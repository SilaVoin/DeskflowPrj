create schema if not exists extensions;
create extension if not exists pgcrypto with schema extensions;

create or replace function public.invite_member_by_email_v2(
  p_org_id uuid,
  p_email text,
  p_role text default 'member'
)
returns json
language plpgsql
security definer
set search_path to 'public'
as $function$
declare
  v_caller_id uuid;
  v_caller_role text;
  v_existing_member organization_members%rowtype;
  v_existing_invite organization_invites%rowtype;
  v_invite organization_invites%rowtype;
  v_target_user_id uuid;
  v_email text;
  v_invite_code text;
  v_invite_token text;
begin
  v_caller_id := auth.uid();
  if v_caller_id is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  v_email := lower(trim(p_email));
  if v_email = '' then
    raise exception 'INVALID_EMAIL';
  end if;

  if position('@' in v_email) <= 1 then
    raise exception 'INVALID_EMAIL';
  end if;

  if p_role not in ('owner', 'admin', 'member') then
    raise exception 'INVALID_ROLE';
  end if;

  select role into v_caller_role
  from public.organization_members
  where organization_id = p_org_id
    and user_id = v_caller_id;

  if v_caller_role is null or v_caller_role not in ('owner', 'admin') then
    raise exception 'NOT_ALLOWED';
  end if;

  if v_caller_role = 'admin' and p_role = 'owner' then
    raise exception 'NOT_ALLOWED_ROLE';
  end if;

  select id into v_target_user_id
  from public.profiles
  where lower(email) = v_email;

  if v_target_user_id is not null then
    select * into v_existing_member
    from public.organization_members
    where organization_id = p_org_id
      and user_id = v_target_user_id;

    if v_existing_member is not null then
      raise exception 'ALREADY_MEMBER';
    end if;
  end if;

  loop
    v_invite_code := upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 8));
    exit when not exists (
      select 1
      from public.organization_invites
      where invite_code = v_invite_code
    );
  end loop;

  loop
    v_invite_token := encode(extensions.gen_random_bytes(24), 'hex');
    exit when not exists (
      select 1
      from public.organization_invites
      where invite_token = v_invite_token
    );
  end loop;

  select * into v_existing_invite
  from public.organization_invites
  where organization_id = p_org_id
    and lower(email) = v_email
    and status = 'pending';

  if v_existing_invite is null then
    insert into public.organization_invites (
      organization_id,
      email,
      role,
      invite_code,
      invite_token,
      status,
      invited_by,
      expires_at,
      last_sent_at,
      updated_at
    )
    values (
      p_org_id,
      v_email,
      p_role,
      v_invite_code,
      v_invite_token,
      'pending',
      v_caller_id,
      now() + interval '14 days',
      now(),
      now()
    )
    returning * into v_invite;
  else
    update public.organization_invites
    set role = p_role,
        invite_code = v_invite_code,
        invite_token = v_invite_token,
        invited_by = v_caller_id,
        expires_at = now() + interval '14 days',
        last_sent_at = now(),
        updated_at = now()
    where id = v_existing_invite.id
    returning * into v_invite;
  end if;

  return json_build_object(
    'id', v_invite.id,
    'organization_id', v_invite.organization_id,
    'email', v_invite.email,
    'role', v_invite.role,
    'invite_code', v_invite.invite_code,
    'invite_token', v_invite.invite_token,
    'status', v_invite.status,
    'expires_at', v_invite.expires_at,
    'last_sent_at', v_invite.last_sent_at
  );
end;
$function$;
