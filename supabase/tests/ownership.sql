-- Run in LOCAL Studio SQL editor. Entire fixture rolls back, including Auth rows.
-- Run fixtures in a transaction so the final rollback removes every test change.
begin;
-- Create two temporary Auth users with deterministic IDs for ownership tests.
insert into auth.users(id,email) values
 -- Create Alice's temporary Auth fixture; the final rollback removes it.
 ('11111111-1111-4111-8111-111111111111','alice-rls@example.com'),
 -- Create Bob's temporary Auth fixture; the final rollback removes it.
 ('22222222-2222-4222-8222-222222222222','bob-rls@example.com');
-- Run subsequent table operations as the normal signed-in client role.
set local role authenticated;
-- Set the transaction's simulated JWT subject to Alice so auth.uid() resolves to her ID.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
-- Create the profile owned by the current simulated user.
insert into public.profiles(id,username,display_name) values (auth.uid(),'alice_rls','Alice');
-- Create Alice's post as the shared ownership fixture.
insert into public.posts(author_id,body) values(auth.uid(),'Ownership fixture');
-- Switch the simulated JWT subject to Bob for cross-user access checks.
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
-- Create the profile owned by the current simulated user.
insert into public.profiles(id,username,display_name) values(auth.uid(),'bob_rls','Bob');
-- Execute procedural assertions; any unexpected permission result raises a FAIL exception.
do $$
-- Keep the affected-row count and fixture post ID for the checks below.
declare n int; p uuid;
-- Start a PL/pgSQL block; nested blocks catch only the expected database error.
begin
 -- Find Alice's fixture post through the current user's normal SELECT permissions.
 select id into p from public.posts where body='Ownership fixture';
 -- Fail if Bob cannot read the shared post, since authenticated feed reading should be allowed.
 if p is null then raise exception 'FAIL: Bob cannot read Alice post'; end if;
 -- Attempt to edit Alice's post as Bob; the ownership policy should affect zero rows.
 update public.posts set body='Attack' where id=p;
 -- Capture how many rows the preceding database mutation affected.
 get diagnostics n=row_count;
 -- Fail if a cross-user edit/deletion affected any protected row.
 if n<>0 then raise exception 'FAIL: Bob edited Alice post'; end if;
 -- Attempt deletion as the current simulated user; the following assertions verify its outcome.
 delete from public.posts where id=p;
 -- Capture how many rows the preceding database mutation affected.
 get diagnostics n=row_count;
 -- Fail if a cross-user edit/deletion affected any protected row.
 if n<>0 then raise exception 'FAIL: Bob deleted Alice post'; end if;
 -- Start a PL/pgSQL block; nested blocks catch only the expected database error.
 begin
   -- Attempt to forge Alice's author ID while authenticated as Bob.
   insert into public.posts(author_id,body) values('11111111-1111-4111-8111-111111111111','Forgery');
   -- Fail this test if execution reaches an operation that should have been rejected.
   raise exception 'FAIL: author spoofing succeeded';
 -- Accept the expected permission denial; other errors still fail the test.
 exception when insufficient_privilege then null; end;
 -- Insert Bob's like; repeating the same user/post pair must violate uniqueness.
 insert into public.likes(post_id,user_id) values(p,auth.uid());
 -- Start a PL/pgSQL block; nested blocks catch only the expected database error.
 begin
   -- Insert Bob's like; repeating the same user/post pair must violate uniqueness.
   insert into public.likes(post_id,user_id) values(p,auth.uid());
   -- Fail this test if execution reaches an operation that should have been rejected.
   raise exception 'FAIL: duplicate like succeeded';
 -- Accept only the duplicate-like uniqueness error for this nested block.
 exception when unique_violation then null; end;
 -- Create Bob's reply on Alice's post to test shared reading and later cascades.
 insert into public.comments(post_id,author_id,body) values(p,auth.uid(),'Bob comment');
 -- Verify that the feed view reports the one stored like.
 if (select like_count from public.feed where id=p)<>1 then raise exception 'FAIL: like count'; end if;
 -- Verify that the feed reports the current simulated user's own liked state.
 if not (select liked from public.feed where id=p) then raise exception 'FAIL: liked flag'; end if;
 -- Start a PL/pgSQL block; nested blocks catch only the expected database error.
 begin
   -- Attempt to take ownership through an update; column grants must reject it.
   update public.posts set author_id=auth.uid() where id=p;
   -- Fail this test if execution reaches an operation that should have been rejected.
   raise exception 'FAIL: ownership column writable';
 -- Accept the expected permission denial; other errors still fail the test.
 exception when insufficient_privilege then null; end;
 -- Start a PL/pgSQL block; nested blocks catch only the expected database error.
 begin
   -- Attempt to point Bob's profile at Alice's avatar folder.
   update public.profiles set avatar_path='11111111-1111-4111-8111-111111111111/fake.jpg' where id=auth.uid();
   -- Fail this test if execution reaches an operation that should have been rejected.
   raise exception 'FAIL: cross-user avatar path';
 -- Accept only the owner-folder CHECK failure for the forged avatar reference.
 exception when check_violation then null; end;
-- Finish this group of database assertions.
end $$;
-- Set the transaction's simulated JWT subject to Alice so auth.uid() resolves to her ID.
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
-- Execute procedural assertions; any unexpected permission result raises a FAIL exception.
do $$
-- Keep the affected-row count and fixture post ID for the checks below.
declare n int; p uuid;
-- Start a PL/pgSQL block; nested blocks catch only the expected database error.
begin
 -- Find Alice's fixture post through the current user's normal SELECT permissions.
 select id into p from public.posts where body='Ownership fixture';
 -- Attempt to delete Bob's individual reply as Alice; owning the post is insufficient.
 delete from public.comments where post_id=p;
 -- Capture how many rows the preceding database mutation affected.
 get diagnostics n=row_count;
 -- Fail if a cross-user edit/deletion affected any protected row.
 if n<>0 then raise exception 'FAIL: Alice deleted Bob comment directly'; end if;
 -- Confirm Alice can edit her own post body.
 update public.posts set body='Updated fixture' where id=p;
 -- Capture how many rows the preceding database mutation affected.
 get diagnostics n=row_count;
 -- Require exactly one affected row for Alice's authorized post edit.
 if n<>1 then raise exception 'FAIL: own edit'; end if;
 -- Attempt deletion as the current simulated user; the following assertions verify its outcome.
 delete from public.posts where id=p;
 -- Verify deleting the owning post also removed its replies through the foreign-key cascade.
 if exists(select 1 from public.comments where post_id=p) then raise exception 'FAIL: comment cascade'; end if;
 -- Verify the same post deletion also removed its likes.
 if exists(select 1 from public.likes where post_id=p) then raise exception 'FAIL: like cascade'; end if;
-- Finish this group of database assertions.
end $$;
-- Switch to the signed-out role for the final access check.
set local role anon;
-- Execute procedural assertions; any unexpected permission result raises a FAIL exception.
do $$ begin
  -- Start a PL/pgSQL block; nested blocks catch only the expected database error.
  begin
    -- Attempt an anonymous read, which the table grants should deny.
    perform * from public.posts;
    -- Fail this test if execution reaches an operation that should have been rejected.
    raise exception 'FAIL: anonymous read';
  -- Accept the expected permission denial; other errors still fail the test.
  exception when insufficient_privilege then null; end;
-- Finish this group of database assertions.
end $$;
-- Remove all fixture Auth users, profiles, posts, replies, and likes created by this test.
rollback;
-- Successful completion with no FAIL exception = checks passed.
