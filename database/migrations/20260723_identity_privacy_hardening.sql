-- Football Network: explicit privilege hardening for private member data.

begin;

revoke all on table member_private_profiles from public, anon, authenticated;
grant select on table member_private_profiles to authenticated;

revoke all on table identity_verification_requests from public, anon, authenticated;
grant select on table identity_verification_requests to authenticated;
grant all on table identity_verification_requests to service_role;

revoke all on table profile_privacy_settings from public, anon, authenticated;
grant select on table profile_privacy_settings to anon, authenticated;

revoke all on function complete_member_onboarding(jsonb) from public, anon;
revoke all on function save_profile_privacy(jsonb) from public, anon;
revoke all on function save_private_identity(jsonb) from public, anon;
revoke all on function request_identity_verification(jsonb) from public, anon;
revoke all on function cancel_identity_verification(uuid) from public, anon;
revoke all on function can_message_profile(uuid, uuid) from public, anon;

grant execute on function complete_member_onboarding(jsonb) to authenticated;
grant execute on function save_profile_privacy(jsonb) to authenticated;
grant execute on function save_private_identity(jsonb) to authenticated;
grant execute on function request_identity_verification(jsonb) to authenticated;
grant execute on function cancel_identity_verification(uuid) to authenticated;

commit;
