-- HOA Voting Tool: example data, so the site looks like a building already using it.
-- Run once in the Supabase SQL Editor. It adds to what is there and does not change your own rows.
-- To remove it later, run the two statements at the bottom of this file.

do $$
declare
  fence bigint; cams bigint; elev bigint; guard bigint; ev bigint; party bigint; land bigint; lobby bigint; t bigint;
  d text := '@users.hoa.invalid';
begin
  -- 24 example units. Owners with a date have "joined"; the rest are not on the system yet.
  insert into roster (unit, owner, email, joined_at) values
    ('101','Dennis Okafor','demo-dennis'||d, now()), ('102','Marisol Vega','demo-marisol'||d, now()),
    ('103','Priya Raman','demo-priya'||d, now()),    ('104','Tom Halloran','demo-tom'||d, null),
    ('201','Grace Lindqvist','demo-grace'||d, now()),('202','Grace Lindqvist','demo-grace'||d, now()),
    ('203','Andre Baptiste','demo-andre'||d, now()), ('204','Wei Chen','demo-wei'||d, null),
    ('301','Rosa Delgado','demo-rosa'||d, now()),    ('302','Sam Whitfield','demo-sam'||d, null),
    ('303','Nadia Haddad','demo-nadia'||d, now()),   ('304','Luis Ferreira','demo-luis'||d, now()),
    ('401','Helen Park','demo-helen'||d, null),      ('402','Jorge Ibarra','demo-jorge'||d, now()),
    ('403','Jorge Ibarra','demo-jorge'||d, now()),   ('404','Beth Nakamura','demo-beth'||d, now()),
    ('501','Omar Siddiqui','demo-omar'||d, null),    ('502','Claire Dubois','demo-claire'||d, now()),
    ('503','Ray Kowalski','demo-ray'||d, null),      ('504','Tanya Brooks','demo-tanya'||d, now()),
    ('601','Marisol Vega','demo-marisol'||d, now()), ('602','Victor Mensah','demo-victor'||d, null),
    ('603','Victor Mensah','demo-victor'||d, null),  ('604','Ingrid Solberg','demo-ingrid'||d, now())
  on conflict (unit) do nothing;

  -- ===== AGENDA: vote open =====
  insert into items (status, title, body, author, deadline) values ('agenda', 'Replace the east perimeter fence',
    'Three posts on the east side have rotted through and a section is leaning into the parking lot. Do we replace the full run now or patch it again? Three contractors have bid on a full replacement in powder-coated aluminum.',
    'Dennis Okafor', date '2026-12-15') returning id into fence;
  insert into bids (item_id, contractor, amount, created_by) values
    (fence,'Bayside Builders',16900,'Dennis Okafor'), (fence,'Coastal Fence Co.',18400,'Dennis Okafor'), (fence,'Ironline Fabrication',22750,'Dennis Okafor');
  insert into votes (item_id, unit, choice) select fence, u, 'yes' from unnest(array['101','201','202','203','301','304','404','504']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into votes (item_id, unit, choice) select fence, u, 'no' from unnest(array['103','402','403']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');

  insert into threads (item_id, stance, title, summary, detail, author) values (fence, 'for', 'A third patch is wasted money',
    'We patched it in 2023 and 2025. A third patch costs almost a quarter of a full replacement.',
    'The 2023 patch was $2,900 and the 2025 patch was $3,600. Both failed within two winters because the posts next to the repaired ones were already soft. All three bidders include a 10-year warranty on a full replacement.',
    'Dennis Okafor') returning id into t;
  insert into replies (thread_id, author, body) values
    (t,'Jorge Ibarra','Fair, but a patch buys us a year to rebuild the reserve.'),
    (t,'Rosa Delgado','It also leans further every storm. I would not wait.'),
    (t,'Grace Lindqvist','Agreed. I park next to it and it moved again last week.');
  insert into upvotes (thread_id, owner) values (t,'Grace Lindqvist'),(t,'Rosa Delgado'),(t,'Luis Ferreira'),(t,'Tanya Brooks');

  insert into threads (item_id, stance, title, summary, detail, author) values (fence, 'against', 'Patch now, replace next fall',
    'The reserve is thin after the roof. I would rather patch and revisit next fall.',
    'The roof took the reserve down to about four months of operating costs. I collected two patch-only quotes, listed below, so we can compare them with the full replacement bids.',
    'Jorge Ibarra') returning id into t;
  insert into bids (item_id, thread_id, contractor, amount, created_by) values
    (fence,t,'Harbor Handyman (patch 3 posts)',4200,'Jorge Ibarra'), (fence,t,'Coastal Fence Co. (patch 3 posts)',4850,'Jorge Ibarra');
  insert into replies (thread_id, author, body) values (t,'Priya Raman','This is the option I can support. Same reason I voted no on the full job.');
  insert into upvotes (thread_id, owner) values (t,'Priya Raman'),(t,'Beth Nakamura');

  insert into threads (item_id, stance, title, summary, detail, author) values (fence, 'question', 'Is haul-away included?',
    'Does the Bayside bid include hauling away the old fence, or is that extra?', '', 'Nadia Haddad') returning id into t;
  insert into replies (thread_id, author, body) values (t,'Dennis Okafor','I asked. Bayside and Coastal include it. Ironline charges $600 extra.');
  insert into upvotes (thread_id, owner) values (t,'Claire Dubois');

  insert into items (status, title, body, author, deadline) values ('agenda', 'Replace the lobby and garage security cameras',
    'Four of the eight cameras no longer record and the system cannot be viewed remotely. The proposal is to replace all eight with a system the board and the management company can check from a phone.',
    'Beth Nakamura', date '2026-12-01') returning id into cams;
  insert into bids (item_id, contractor, amount, created_by) values
    (cams,'SafeSight Systems',7400,'Beth Nakamura'), (cams,'Keystone Security',8950,'Beth Nakamura');
  insert into votes (item_id, unit, choice) select cams, u, 'yes' from unnest(array['404','502','504','604','301','303']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into votes (item_id, unit, choice) select cams, u, 'no' from unnest(array['203']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into threads (item_id, stance, title, summary, detail, author) values (cams, 'for', 'Two break-ins in the garage this year',
    'Both times the camera covering the bike room was one of the dead ones. We had nothing to give the police.', '', 'Tanya Brooks') returning id into t;
  insert into upvotes (thread_id, owner) values (t,'Beth Nakamura'),(t,'Ingrid Solberg'),(t,'Claire Dubois');
  insert into threads (item_id, stance, title, summary, detail, author) values (cams, 'question', 'Who can view the footage?',
    'Before I vote I would like a written rule on who can log in and how long recordings are kept.', '', 'Andre Baptiste') returning id into t;
  insert into replies (thread_id, author, body) values (t,'Beth Nakamura','Good point. I will add a draft policy as a document this week.');

  -- ===== AGENDA: decided =====
  insert into items (status, title, body, author, deadline) values ('passed', 'Approve the 2027 elevator maintenance contract',
    'Our current contract ends December 31. Both bids cover monthly service and the annual inspection.',
    'Marisol Vega', date '2026-11-30') returning id into elev;
  insert into bids (item_id, contractor, amount, created_by) values (elev,'Vertex Elevator',9600,'Marisol Vega'), (elev,'Sunline Lift Services',11200,'Marisol Vega');
  insert into votes (item_id, unit, choice) select elev, u, 'yes' from unnest(array['601','102','101','103','201','202','203','301','303','304','402','403','404','502','504','604']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into threads (item_id, stance, title, summary, detail, author) values (elev, 'for', 'Stay with Vertex',
    'Vertex has been reliable for three years and is the lower bid. No reason to switch.', '', 'Grace Lindqvist') returning id into t;
  insert into upvotes (thread_id, owner) values (t,'Dennis Okafor'),(t,'Nadia Haddad');

  insert into items (status, title, body, author) values ('failed', 'Hire an overnight security guard',
    'A guard in the lobby from 10 pm to 6 am, seven nights a week. This would raise monthly dues by roughly $85 per unit.',
    'Luis Ferreira') returning id into guard;
  insert into bids (item_id, contractor, amount, created_by) values (guard,'Sentinel Guard Services (per year)',68000,'Luis Ferreira'), (guard,'NightWatch Patrol (per year)',74500,'Luis Ferreira');
  insert into votes (item_id, unit, choice) select guard, u, 'yes' from unnest(array['304','504','404','303','101']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into votes (item_id, unit, choice) select guard, u, 'no' from unnest(array['201','202','203','402','403','103','502','604']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into threads (item_id, stance, title, summary, detail, author) values (guard, 'against', 'Cameras first, then decide',
    'This costs nine times what new cameras cost. Let us fix the cameras and see if that is enough.', '', 'Claire Dubois') returning id into t;
  insert into upvotes (thread_id, owner) values (t,'Grace Lindqvist'),(t,'Jorge Ibarra'),(t,'Priya Raman'),(t,'Ingrid Solberg');

  -- ===== PROPOSALS =====
  insert into items (title, body, author) values ('Add EV chargers to the garage',
    'Four of us now drive electric cars and charge elsewhere. I would like the board to collect bids for two shared chargers on level P1, with each driver paying for their own electricity through an app.',
    'Jorge Ibarra') returning id into ev;
  insert into supports (item_id, unit) select ev, u from unnest(array['402','403','201','202','604']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into bids (item_id, contractor, amount, created_by) values (ev,'VoltPoint Installers (rough estimate)',11800,'Jorge Ibarra');
  insert into threads (item_id, stance, title, summary, detail, author) values (ev, 'for', 'Good for resale value',
    'Buyers are starting to ask about charging. This will matter for resale within a few years.', '', 'Ingrid Solberg') returning id into t;
  insert into upvotes (thread_id, owner) values (t,'Jorge Ibarra'),(t,'Grace Lindqvist');
  insert into threads (item_id, stance, title, summary, detail, author) values (ev, 'question', 'Can our electrical panel handle it?',
    'The building is from 1988. Has anyone checked whether the garage panel has spare capacity?', '', 'Dennis Okafor') returning id into t;
  insert into replies (thread_id, author, body) values (t,'Jorge Ibarra','VoltPoint says two chargers fit on the existing panel. A third would need an upgrade.');

  insert into items (title, body, author) values ('End-of-year rooftop party',
    'A potluck on the roof deck the second Saturday of December. Asking for up to $400 from the social budget for heaters and drinks.',
    'Claire Dubois') returning id into party;
  insert into supports (item_id, unit) select party, u from unnest(array['502','504','301']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into threads (item_id, stance, title, summary, detail, author) values (party, 'for', 'I can bring the speakers',
    'Happy to handle music, and my brother has two patio heaters we can borrow for free.', '', 'Tanya Brooks') returning id into t;
  insert into upvotes (thread_id, owner) values (t,'Claire Dubois');

  insert into items (title, body, author) values ('Switch landscaping companies',
    'The hedges along the front walk were not trimmed for most of the summer and two palms were lost. Our contract renews in February, so now is the time to compare.',
    'Rosa Delgado') returning id into land;
  insert into supports (item_id, unit) select land, u from unnest(array['301','303']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
  insert into bids (item_id, contractor, amount, created_by) values (land,'GreenLine Grounds (per year)',14400,'Rosa Delgado'), (land,'Palm & Path Landscaping (per year)',15900,'Rosa Delgado'), (land,'Current company (per year)',13200,'Rosa Delgado');
  insert into threads (item_id, stance, title, summary, detail, author) values (land, 'against', 'Give them one written warning first',
    'They have been fine for six years. A formal notice with a checklist is cheaper than switching.', '', 'Andre Baptiste') returning id into t;
  insert into replies (thread_id, author, body) values (t,'Rosa Delgado','We sent one in June. Nothing changed, which is why I am raising this.');

  -- ===== SHELVED =====
  insert into items (status, title, body, author) values ('shelved', 'Repaint the lobby',
    'The lobby walls are scuffed and the color is dated. Shelved until the fence and camera decisions are made.',
    'Beth Nakamura') returning id into lobby;
  insert into supports (item_id, unit) select lobby, u from unnest(array['404']) u where exists (select 1 from roster r where r.unit = u and r.email like 'demo-%');
end $$;

-- To remove the example data later, run these two statements:
-- delete from items where author in ('Dennis Okafor','Beth Nakamura','Marisol Vega','Luis Ferreira','Jorge Ibarra','Claire Dubois','Rosa Delgado');
-- delete from roster where email like 'demo-%@users.hoa.invalid';
