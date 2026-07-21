-- Football Network: public read access for active reference data.

begin;

alter table supported_locales enable row level security;

drop policy if exists "Active locales are readable" on supported_locales;
create policy "Active locales are readable"
  on supported_locales for select
  using (is_enabled);

grant select on supported_locales to anon, authenticated;

commit;
