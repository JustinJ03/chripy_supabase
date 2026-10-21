-- Application data: authentication credentials remain in Supabase Auth.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null unique check (username ~ '^[a-z0-9_]{3,24}$'),
  display_name text not null check (char_length(btrim(display_name)) between 1 and 50),
  bio text not null default '' check (char_length(bio) <= 160),
  avatar_path text check (avatar_path is null or avatar_path like id::text || '/%'),
  created_at timestamptz not null default now()
);
create table public.posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 280),
  created_at timestamptz not null default now()
);
create table public.comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references public.posts(id) on delete cascade,
  author_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(btrim(body)) between 1 and 280),
  created_at timestamptz not null default now()
);
create table public.likes (
  post_id uuid not null references public.posts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (post_id, user_id)
);
create index posts_feed on public.posts(created_at desc, id desc);
create index posts_author on public.posts(author_id, created_at desc, id desc);
create index comments_post on public.comments(post_id, created_at desc, id desc);
create index comments_author on public.comments(author_id);
create index likes_user on public.likes(user_id);

alter table public.profiles enable row level security;
alter table public.posts enable row level security;
alter table public.comments enable row level security;
alter table public.likes enable row level security;
revoke all on public.profiles,public.posts,public.comments,public.likes from anon,authenticated;
grant select on public.profiles,public.posts,public.comments,public.likes to authenticated;
grant insert(id,username,display_name,bio,avatar_path) on public.profiles to authenticated;
grant update(username,display_name,bio,avatar_path) on public.profiles to authenticated;
grant insert(author_id,body) on public.posts to authenticated;
grant update(body) on public.posts to authenticated;
grant delete on public.posts to authenticated;
grant insert(post_id,author_id,body) on public.comments to authenticated;
grant delete on public.comments to authenticated;
grant insert(post_id,user_id) on public.likes to authenticated;
grant delete on public.likes to authenticated;

create policy profiles_read on public.profiles for select to authenticated using (true);
create policy profiles_create on public.profiles for insert to authenticated with check (id=(select auth.uid()));
create policy profiles_edit on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
create policy posts_read on public.posts for select to authenticated using (true);
create policy posts_create on public.posts for insert to authenticated with check (author_id=(select auth.uid()));
create policy posts_edit on public.posts for update to authenticated using (author_id=(select auth.uid())) with check (author_id=(select auth.uid()));
create policy posts_delete on public.posts for delete to authenticated using (author_id=(select auth.uid()));
create policy comments_read on public.comments for select to authenticated using (true);
create policy comments_create on public.comments for insert to authenticated with check (author_id=(select auth.uid()));
create policy comments_delete on public.comments for delete to authenticated using (author_id=(select auth.uid()));
create policy likes_read on public.likes for select to authenticated using (true);
create policy likes_create on public.likes for insert to authenticated with check (user_id=(select auth.uid()));
create policy likes_delete on public.likes for delete to authenticated using (user_id=(select auth.uid()));

-- Security-invoker views preserve the requesting user's underlying RLS rules.
create view public.feed with (security_invoker=true) as
select p.*, u.username,u.display_name,u.avatar_path,
  (select count(*) from public.likes l where l.post_id=p.id) as like_count,
  (select count(*) from public.comments c where c.post_id=p.id) as comment_count,
  exists(select 1 from public.likes l where l.post_id=p.id and l.user_id=auth.uid()) as liked
from public.posts p join public.profiles u on u.id=p.author_id;
create view public.comment_feed with (security_invoker=true) as
select c.*, u.username,u.display_name,u.avatar_path
from public.comments c join public.profiles u on u.id=c.author_id;
revoke all on public.feed,public.comment_feed from anon,authenticated;
grant select on public.feed,public.comment_feed to authenticated;

-- Private avatars: read only while authenticated, write only in your UID folder.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values ('avatars','avatars',false,2097152,array['image/jpeg','image/png'])
on conflict (id) do update set public=false,file_size_limit=2097152,
  allowed_mime_types=array['image/jpeg','image/png'];
create policy chripy_avatar_read on storage.objects for select to authenticated using (bucket_id='avatars');
create policy chripy_avatar_insert on storage.objects for insert to authenticated
with check (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy chripy_avatar_delete on storage.objects for delete to authenticated
using (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Replacements use new paths, so no UPDATE/upsert permission is needed.
