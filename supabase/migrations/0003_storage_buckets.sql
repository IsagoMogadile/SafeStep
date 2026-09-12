insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('avatars', 'avatars', true, 5242880, array['image/png','image/jpeg','image/webp']),
  ('incident-photos', 'incident-photos', false, 10485760, array['image/png','image/jpeg','image/webp'])
on conflict (id) do nothing;

drop policy if exists "Avatar images are publicly readable" on storage.objects;
create policy "Avatar images are publicly readable"
on storage.objects for select
using (bucket_id = 'avatars');

drop policy if exists "Users can upload their own avatar" on storage.objects;
create policy "Users can upload their own avatar"
on storage.objects for insert
with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users can update their own avatar" on storage.objects;
create policy "Users can update their own avatar"
on storage.objects for update
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Users can delete their own avatar" on storage.objects;
create policy "Users can delete their own avatar"
on storage.objects for delete
using (bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Students can upload their own incident photos" on storage.objects;
create policy "Students can upload their own incident photos"
on storage.objects for insert
with check (bucket_id = 'incident-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Students can read their own incident photos" on storage.objects;
create policy "Students can read their own incident photos"
on storage.objects for select
using (bucket_id = 'incident-photos' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "Responders can read incident photos" on storage.objects;
create policy "Responders can read incident photos"
on storage.objects for select
using (bucket_id = 'incident-photos' and is_responder());
