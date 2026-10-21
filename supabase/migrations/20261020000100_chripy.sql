-- Application data: authentication credentials remain in Supabase Auth.
-- Store public-facing account details; passwords and credentials remain in Supabase Auth.
create table public.profiles (
  -- Use the Auth user ID as the profile ID and remove the profile if its Auth account is deleted.
  id uuid primary key references auth.users(id) on delete cascade,
  -- Require a unique username matching the app's lowercase ASCII format and length.
  username text not null unique check (username ~ '^[a-z0-9_]{3,24}$'),
  -- Enforce a nonempty display name of at most fifty trimmed Unicode code points.
  display_name text not null check (char_length(btrim(display_name)) between 1 and 50),
  -- Default the optional biography to empty text and enforce its 160-code-point limit.
  bio text not null default '' check (char_length(bio) <= 160),
  -- Allow no avatar or a storage path starting with this profile's UUID folder.
  avatar_path text check (avatar_path is null or avatar_path like id::text || '/%'),
  -- Record a server timestamp; client grants below do not allow it to be edited.
  created_at timestamptz not null default now()
);
-- Store short text posts, each attached to one existing profile.
create table public.posts (
  -- Generate a unique content ID on the database server.
  id uuid primary key default gen_random_uuid(),
  -- Link content to its author and remove it if that profile is deleted.
  author_id uuid not null references public.profiles(id) on delete cascade,
  -- Enforce the one-to-280 trimmed code-point body limit independently of Flutter validation.
  body text not null check (char_length(btrim(body)) between 1 and 280),
  -- Record a server timestamp; client grants below do not allow it to be edited.
  created_at timestamptz not null default now()
);
-- Store text replies attached to a post and an author profile.
create table public.comments (
  -- Generate a unique content ID on the database server.
  id uuid primary key default gen_random_uuid(),
  -- Attach this row to a post and delete it automatically when that post is removed.
  post_id uuid not null references public.posts(id) on delete cascade,
  -- Link content to its author and remove it if that profile is deleted.
  author_id uuid not null references public.profiles(id) on delete cascade,
  -- Enforce the one-to-280 trimmed code-point body limit independently of Flutter validation.
  body text not null check (char_length(btrim(body)) between 1 and 280),
  -- Record a server timestamp; client grants below do not allow it to be edited.
  created_at timestamptz not null default now()
);
-- Store one relationship per user/post pair rather than a mutable client-side counter.
create table public.likes (
  -- Attach this row to a post and delete it automatically when that post is removed.
  post_id uuid not null references public.posts(id) on delete cascade,
  -- Attach this like to a profile and remove it when that profile is deleted.
  user_id uuid not null references public.profiles(id) on delete cascade,
  -- Record a server timestamp; client grants below do not allow it to be edited.
  created_at timestamptz not null default now(),
  -- Prevent duplicate likes by making the post/user combination unique.
  primary key (post_id, user_id)
);
-- Speed up global feed ordering and keyset pagination by timestamp and ID.
create index posts_feed on public.posts(created_at desc, id desc);
-- Speed up a single author's timeline with the same stable ordering.
create index posts_author on public.posts(author_id, created_at desc, id desc);
-- Speed up paginated conversation queries for a selected post.
create index comments_post on public.comments(post_id, created_at desc, id desc);
-- Index the reply-author foreign key for author lookups and cascades.
create index comments_author on public.comments(author_id);
-- Index the like-owner foreign key for per-user lookups and cascades.
create index likes_user on public.likes(user_id);

-- Enable Row Level Security so table access also requires a matching policy.
alter table public.profiles enable row level security;
-- Enable Row Level Security so table access also requires a matching policy.
alter table public.posts enable row level security;
-- Enable Row Level Security so table access also requires a matching policy.
alter table public.comments enable row level security;
-- Enable Row Level Security so table access also requires a matching policy.
alter table public.likes enable row level security;
-- Remove inherited client privileges before granting the minimum required operations.
revoke all on public.profiles,public.posts,public.comments,public.likes from anon,authenticated;
-- Allow authenticated reads; the SELECT policies still control row visibility.
grant select on public.profiles,public.posts,public.comments,public.likes to authenticated;
-- Allow onboarding to supply only these profile fields, excluding server timestamps.
grant insert(id,username,display_name,bio,avatar_path) on public.profiles to authenticated;
-- Permit profile text/photo updates while protecting profile ID and creation time.
grant update(username,display_name,bio,avatar_path) on public.profiles to authenticated;
-- Allow post creation with author/body only; IDs and timestamps come from the server.
grant insert(author_id,body) on public.posts to authenticated;
-- Allow changing post text without permitting ownership, ID, or timestamp changes.
grant update(body) on public.posts to authenticated;
-- Allow post deletion only where the owner DELETE policy below matches.
grant delete on public.posts to authenticated;
-- Allow reply creation with a post, author, and body, but no client-set timestamp.
grant insert(post_id,author_id,body) on public.comments to authenticated;
-- Allow reply deletion only under the author ownership policy.
grant delete on public.comments to authenticated;
-- Allow a user/post like relationship to be inserted under its ownership policy.
grant insert(post_id,user_id) on public.likes to authenticated;
-- Allow like removal only under the user ownership policy.
grant delete on public.likes to authenticated;

-- Allow all authenticated users to read these social records.
create policy profiles_read on public.profiles for select to authenticated using (true);
-- Require inserted ownership IDs to match auth.uid(), blocking author/user spoofing.
create policy profiles_create on public.profiles for insert to authenticated with check (id=(select auth.uid()));
-- Require both the original and resulting row to belong to the signed-in user.
create policy profiles_edit on public.profiles for update to authenticated using (id=(select auth.uid())) with check (id=(select auth.uid()));
-- Allow all authenticated users to read these social records.
create policy posts_read on public.posts for select to authenticated using (true);
-- Require inserted ownership IDs to match auth.uid(), blocking author/user spoofing.
create policy posts_create on public.posts for insert to authenticated with check (author_id=(select auth.uid()));
-- Require both the original and resulting row to belong to the signed-in user.
create policy posts_edit on public.posts for update to authenticated using (author_id=(select auth.uid())) with check (author_id=(select auth.uid()));
-- Allow deletion only when this row belongs to the signed-in user.
create policy posts_delete on public.posts for delete to authenticated using (author_id=(select auth.uid()));
-- Allow all authenticated users to read these social records.
create policy comments_read on public.comments for select to authenticated using (true);
-- Require inserted ownership IDs to match auth.uid(), blocking author/user spoofing.
create policy comments_create on public.comments for insert to authenticated with check (author_id=(select auth.uid()));
-- Allow deletion only when this row belongs to the signed-in user.
create policy comments_delete on public.comments for delete to authenticated using (author_id=(select auth.uid()));
-- Allow all authenticated users to read these social records.
create policy likes_read on public.likes for select to authenticated using (true);
-- Require inserted ownership IDs to match auth.uid(), blocking author/user spoofing.
create policy likes_create on public.likes for insert to authenticated with check (user_id=(select auth.uid()));
-- Allow deletion only when this row belongs to the signed-in user.
create policy likes_delete on public.likes for delete to authenticated using (user_id=(select auth.uid()));

-- Security-invoker views preserve the requesting user's underlying RLS rules.
-- Build an enriched feed while applying the querying user's underlying table RLS rules.
create view public.feed with (security_invoker=true) as
-- Include each post together with the current public author details.
select p.*, u.username,u.display_name,u.avatar_path,
  -- Calculate the post's current like count from stored like relationships.
  (select count(*) from public.likes l where l.post_id=p.id) as like_count,
  -- Calculate the current reply count rather than trusting a client-provided counter.
  (select count(*) from public.comments c where c.post_id=p.id) as comment_count,
  -- Expose whether the querying signed-in user has liked this post.
  exists(select 1 from public.likes l where l.post_id=p.id and l.user_id=auth.uid()) as liked
-- Join posts to their authors using the profile foreign key.
from public.posts p join public.profiles u on u.id=p.author_id;
-- Enrich replies with author details while retaining the caller's table permissions.
create view public.comment_feed with (security_invoker=true) as
-- Include reply fields and the current author username, name, and photo path.
select c.*, u.username,u.display_name,u.avatar_path
-- Match each reply to its author profile.
from public.comments c join public.profiles u on u.id=c.author_id;
-- Remove implicit client privileges from both views before explicit grants.
revoke all on public.feed,public.comment_feed from anon,authenticated;
-- Allow authenticated clients to query the two read-only feed views.
grant select on public.feed,public.comment_feed to authenticated;

-- Private avatars: read only while authenticated, write only in your UID folder.
-- Create the private avatars bucket with size and content-type restrictions.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
-- Keep objects private, cap uploads at two megabytes, and accept JPEG/PNG content types.
values ('avatars','avatars',false,2097152,array['image/jpeg','image/png'])
-- Reapply the private flag and file-size restriction if the bucket already exists.
on conflict (id) do update set public=false,file_size_limit=2097152,
  -- Retain the allowed JPEG/PNG MIME types when updating an existing bucket.
  allowed_mime_types=array['image/jpeg','image/png'];
-- Allow authenticated users to download private avatars for profile/feed display.
create policy chripy_avatar_read on storage.objects for select to authenticated using (bucket_id='avatars');
-- Add the avatar INSERT policy; the following check validates bucket and owner folder.
create policy chripy_avatar_insert on storage.objects for insert to authenticated
-- Accept uploads only in the avatars bucket and the signed-in user's UUID folder.
with check (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Add the avatar DELETE policy; the following USING clause limits deletions to the owner folder.
create policy chripy_avatar_delete on storage.objects for delete to authenticated
-- Allow deletion only from the signed-in user's own folder in the avatars bucket.
using (bucket_id='avatars' and (storage.foldername(name))[1]=(select auth.uid())::text);
-- Replacements use new paths, so no UPDATE/upsert permission is needed.
