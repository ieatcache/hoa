-- HOA Voting Tool: document attachments on proposals.
-- Run this once in the Supabase SQL Editor, after schema.sql.

create table attachments (
  id bigint generated always as identity primary key,
  item_id bigint not null references items on delete cascade,
  name text not null check (char_length(name) between 1 and 200),
  path text not null unique,
  size bigint not null default 0,
  uploaded_by text not null,
  created_at timestamptz not null default now()
);
alter table attachments enable row level security;

-- Owners see every document. The admin, or the person who raised the item, can add them.
create policy attachments_read on attachments for select to authenticated using (is_member());
create policy attachments_insert on attachments for insert to authenticated with check (
  is_member() and uploaded_by = my_name() and (
    is_admin() or exists (select 1 from items i where i.id = item_id and i.author = my_name())));
create policy attachments_delete on attachments for delete to authenticated using (is_admin());

-- Private file storage, 10 MB per file. Only owners on the roster can read or upload.
insert into storage.buckets (id, name, public, file_size_limit)
values ('attachments', 'attachments', false, 10485760)
on conflict (id) do nothing;

create policy hoa_files_read on storage.objects for select to authenticated
  using (bucket_id = 'attachments' and public.is_member());
create policy hoa_files_upload on storage.objects for insert to authenticated
  with check (bucket_id = 'attachments' and public.is_member());
create policy hoa_files_delete on storage.objects for delete to authenticated
  using (bucket_id = 'attachments' and public.is_admin());
