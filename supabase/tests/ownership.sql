-- Run in LOCAL Studio SQL editor. Entire fixture rolls back, including Auth rows.
begin;
insert into auth.users(id,email) values
 ('11111111-1111-4111-8111-111111111111','alice-rls@example.com'),
 ('22222222-2222-4222-8222-222222222222','bob-rls@example.com');
set local role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
insert into public.profiles(id,username,display_name) values (auth.uid(),'alice_rls','Alice');
insert into public.posts(author_id,body) values(auth.uid(),'Ownership fixture');
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',true);
insert into public.profiles(id,username,display_name) values(auth.uid(),'bob_rls','Bob');
do $$
declare n int; p uuid;
begin
 select id into p from public.posts where body='Ownership fixture';
 if p is null then raise exception 'FAIL: Bob cannot read Alice post'; end if;
 update public.posts set body='Attack' where id=p;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL: Bob edited Alice post'; end if;
 delete from public.posts where id=p;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL: Bob deleted Alice post'; end if;
 begin
   insert into public.posts(author_id,body) values('11111111-1111-4111-8111-111111111111','Forgery');
   raise exception 'FAIL: author spoofing succeeded';
 exception when insufficient_privilege then null; end;
 insert into public.likes(post_id,user_id) values(p,auth.uid());
 begin
   insert into public.likes(post_id,user_id) values(p,auth.uid());
   raise exception 'FAIL: duplicate like succeeded';
 exception when unique_violation then null; end;
 insert into public.comments(post_id,author_id,body) values(p,auth.uid(),'Bob comment');
 if (select like_count from public.feed where id=p)<>1 then raise exception 'FAIL: like count'; end if;
 if not (select liked from public.feed where id=p) then raise exception 'FAIL: liked flag'; end if;
 begin
   update public.posts set author_id=auth.uid() where id=p;
   raise exception 'FAIL: ownership column writable';
 exception when insufficient_privilege then null; end;
 begin
   update public.profiles set avatar_path='11111111-1111-4111-8111-111111111111/fake.jpg' where id=auth.uid();
   raise exception 'FAIL: cross-user avatar path';
 exception when check_violation then null; end;
end $$;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',true);
do $$
declare n int; p uuid;
begin
 select id into p from public.posts where body='Ownership fixture';
 delete from public.comments where post_id=p;
 get diagnostics n=row_count;
 if n<>0 then raise exception 'FAIL: Alice deleted Bob comment directly'; end if;
 update public.posts set body='Updated fixture' where id=p;
 get diagnostics n=row_count;
 if n<>1 then raise exception 'FAIL: own edit'; end if;
 delete from public.posts where id=p;
 if exists(select 1 from public.comments where post_id=p) then raise exception 'FAIL: comment cascade'; end if;
 if exists(select 1 from public.likes where post_id=p) then raise exception 'FAIL: like cascade'; end if;
end $$;
set local role anon;
do $$ begin
  begin
    perform * from public.posts;
    raise exception 'FAIL: anonymous read';
  exception when insufficient_privilege then null; end;
end $$;
rollback;
-- Successful completion with no FAIL exception = checks passed.
