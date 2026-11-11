-- HOA Voting Tool: database setup for Supabase.
-- Run this once in the Supabase SQL Editor (paste the whole file, click Run).

-- ---------- Tables ----------
create table settings (
  id int primary key default 1 check (id = 1),
  building text not null default '',
  promote_pct int not null default 25 check (promote_pct between 1 and 100)
);
insert into settings default values;

create table roster (
  unit text primary key,
  owner text not null check (char_length(owner) between 1 and 120),
  email text not null,
  is_admin boolean not null default false,
  joined_at timestamptz
);

create table items (
  id bigint generated always as identity primary key,
  status text not null default 'proposal' check (status in ('proposal','agenda','passed','failed','shelved')),
  rule text not null default 'majority' check (rule in ('majority','twothirds','threequarters')),
  title text not null check (char_length(title) between 1 and 120),
  body text not null default '',
  author text not null,
  deadline date,
  created_at timestamptz not null default now()
);

create table threads (
  id bigint generated always as identity primary key,
  item_id bigint not null references items on delete cascade,
  stance text not null check (stance in ('for','against','question')),
  title text not null check (char_length(title) between 1 and 60),
  summary text not null check (char_length(summary) between 1 and 140),
  detail text not null default '',
  author text not null,
  created_at timestamptz not null default now()
);

create table replies (
  id bigint generated always as identity primary key,
  thread_id bigint not null references threads on delete cascade,
  author text not null,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);

create table bids (
  id bigint generated always as identity primary key,
  item_id bigint not null references items on delete cascade,
  thread_id bigint references threads on delete cascade,
  contractor text not null check (char_length(contractor) between 1 and 120),
  amount numeric not null check (amount >= 0),
  created_by text not null,
  created_at timestamptz not null default now()
);

create table votes (
  item_id bigint not null references items on delete cascade,
  unit text not null references roster (unit) on delete cascade on update cascade,
  choice text not null check (choice in ('yes','no')),
  primary key (item_id, unit)
);

create table supports (
  item_id bigint not null references items on delete cascade,
  unit text not null references roster (unit) on delete cascade on update cascade,
  primary key (item_id, unit)
);

create table upvotes (
  thread_id bigint not null references threads on delete cascade,
  owner text not null,
  primary key (thread_id, owner)
);

-- ---------- Who is calling ----------
create function my_email() returns text language sql stable as $$
  select lower(auth.jwt() ->> 'email')
$$;

create function my_name() returns text language sql stable security definer set search_path = public as $$
  select owner from roster where lower(email) = my_email() order by unit limit 1
$$;

create function is_member() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from roster where lower(email) = my_email())
$$;

create function is_admin() returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from roster where lower(email) = my_email() and is_admin)
$$;

-- Called on every sign-in. Marks the owner as joined and reports who they are.
create function whoami() returns json language plpgsql security definer set search_path = public as $$
begin
  update roster set joined_at = now() where lower(email) = my_email() and joined_at is null;
  return json_build_object(
    'email', my_email(), 'name', my_name(), 'member', is_member(), 'admin', is_admin(),
    'roster_empty', not exists (select 1 from roster));
end $$;

-- The first person to sign in creates the building and becomes its admin.
create function bootstrap(p_building text, p_name text, p_units text[]) returns void
language plpgsql security definer set search_path = public as $$
begin
  if my_email() is null then raise exception 'Sign in first.'; end if;
  lock table roster in exclusive mode;
  if exists (select 1 from roster) then raise exception 'This building is already set up.'; end if;
  if coalesce(array_length(p_units, 1), 0) = 0 or coalesce(trim(p_name), '') = '' then
    raise exception 'Enter your name and at least one unit.';
  end if;
  insert into roster (unit, owner, email, is_admin, joined_at)
    select distinct trim(u), trim(p_name), my_email(), true, now() from unnest(p_units) u where trim(u) <> '';
  update settings set building = coalesce(p_building, '') where id = 1;
end $$;

-- Roster without email addresses, for owners.
create function roster_list() returns table (unit text, owner text, joined boolean)
language sql stable security definer set search_path = public as $$
  select r.unit, r.owner, r.joined_at is not null from roster r where is_member() order by r.unit
$$;

create function votes_needed(p_rule text) returns int language sql stable security definer set search_path = public as $$
  select case p_rule
    when 'twothirds' then ceil(count(*) * 2 / 3.0)::int
    when 'threequarters' then ceil(count(*) * 0.75)::int
    else floor(count(*) / 2.0)::int + 1 end
  from roster
$$;

-- ---------- Voting ----------
-- Casts every one of the caller's units the same way. Pass null to withdraw the vote.
create function cast_vote(p_item bigint, p_choice text) returns void
language plpgsql security definer set search_path = public as $$
declare v_rule text; v_status text;
begin
  if not is_member() then raise exception 'You are not on the roster.'; end if;
  select status, rule into v_status, v_rule from items where id = p_item for update;
  if v_status is distinct from 'agenda' then raise exception 'This vote is not open.'; end if;
  delete from votes where item_id = p_item and unit in (select unit from roster where lower(email) = my_email());
  if p_choice in ('yes', 'no') then
    insert into votes (item_id, unit, choice)
      select p_item, unit, p_choice from roster where lower(email) = my_email();
  end if;
  if (select count(*) from votes where item_id = p_item and choice = 'yes') >= votes_needed(v_rule) then
    update items set status = 'passed' where id = p_item;
  end if;
end $$;

-- Adds or withdraws the caller's support. Enough support moves a proposal to the agenda.
create function toggle_support(p_item bigint) returns void
language plpgsql security definer set search_path = public as $$
declare v_status text; v_need int;
begin
  if not is_member() then raise exception 'You are not on the roster.'; end if;
  select status into v_status from items where id = p_item for update;
  if v_status is distinct from 'proposal' then raise exception 'This is no longer a proposal.'; end if;
  if exists (select 1 from supports s join roster r on r.unit = s.unit where s.item_id = p_item and lower(r.email) = my_email()) then
    delete from supports where item_id = p_item and unit in (select unit from roster where lower(email) = my_email());
  else
    insert into supports (item_id, unit) select p_item, unit from roster where lower(email) = my_email();
  end if;
  select greatest(1, ceil((select count(*) from roster) * promote_pct / 100.0)::int) into v_need from settings where id = 1;
  if (select count(*) from supports where item_id = p_item) >= v_need then
    update items set status = 'agenda' where id = p_item;
  end if;
end $$;

create function toggle_upvote(p_thread bigint) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not is_member() then raise exception 'You are not on the roster.'; end if;
  if exists (select 1 from upvotes where thread_id = p_thread and owner = my_name()) then
    delete from upvotes where thread_id = p_thread and owner = my_name();
  else
    insert into upvotes (thread_id, owner) values (p_thread, my_name());
  end if;
end $$;

-- ---------- Access rules ----------
alter table settings enable row level security;
alter table roster enable row level security;
alter table items enable row level security;
alter table threads enable row level security;
alter table replies enable row level security;
alter table bids enable row level security;
alter table votes enable row level security;
alter table supports enable row level security;
alter table upvotes enable row level security;

create policy settings_read on settings for select to authenticated using (is_member());
create policy settings_admin on settings for update to authenticated using (is_admin()) with check (is_admin());

-- Owners see only their own roster rows (use roster_list() for the rest); the admin sees and edits all.
create policy roster_read on roster for select to authenticated using (is_admin() or lower(email) = my_email());
create policy roster_insert on roster for insert to authenticated with check (is_admin());
create policy roster_update on roster for update to authenticated using (is_admin()) with check (is_admin());
create policy roster_delete on roster for delete to authenticated using (is_admin());

create policy items_read on items for select to authenticated using (is_member());
create policy items_insert on items for insert to authenticated
  with check (is_member() and status = 'proposal' and author = my_name());
create policy items_update on items for update to authenticated using (is_admin()) with check (is_admin());
create policy items_delete on items for delete to authenticated using (is_admin());

create policy threads_read on threads for select to authenticated using (is_member());
create policy threads_insert on threads for insert to authenticated with check (is_member() and author = my_name());
create policy threads_delete on threads for delete to authenticated using (is_admin());

create policy replies_read on replies for select to authenticated using (is_member());
create policy replies_insert on replies for insert to authenticated with check (is_member() and author = my_name());
create policy replies_delete on replies for delete to authenticated using (is_admin());

-- Bids: the admin, the item's author (on the item) or the thread's author (on their thread).
create policy bids_read on bids for select to authenticated using (is_member());
create policy bids_insert on bids for insert to authenticated with check (
  is_member() and created_by = my_name() and (
    is_admin()
    or (thread_id is null and exists (select 1 from items i where i.id = item_id and i.author = my_name()))
    or (thread_id is not null and exists (select 1 from threads t where t.id = thread_id and t.item_id = bids.item_id and t.author = my_name()))
  ));
create policy bids_delete on bids for delete to authenticated using (is_admin());

-- Votes, support and upvotes are readable by owners and written only through the functions above.
create policy votes_read on votes for select to authenticated using (is_member());
create policy supports_read on supports for select to authenticated using (is_member());
create policy upvotes_read on upvotes for select to authenticated using (is_member());

revoke execute on function bootstrap(text, text, text[]), whoami(), roster_list(), cast_vote(bigint, text), toggle_support(bigint), toggle_upvote(bigint) from anon, public;
grant execute on function bootstrap(text, text, text[]), whoami(), roster_list(), cast_vote(bigint, text), toggle_support(bigint), toggle_upvote(bigint) to authenticated;
