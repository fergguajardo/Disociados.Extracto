-- Ejecutar una sola vez en el SQL Editor del proyecto de Supabase de KAIROS.
-- Publica exclusivamente Disociados; no habilita la lectura de kairos_documents.
begin;
create table if not exists public.disociados_publication (
 id text primary key check (id = 'disociados'),
 data jsonb not null,
 updated_at timestamptz not null default now()
);
alter table public.disociados_publication enable row level security;
revoke all on public.disociados_publication from anon, authenticated;
grant select on public.disociados_publication to anon, authenticated;
drop policy if exists "Lectura publica de Disociados" on public.disociados_publication;
create policy "Lectura publica de Disociados" on public.disociados_publication
 for select to anon, authenticated using (id = 'disociados');
create or replace function public.sync_disociados_publication()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
 if new.user_id::text = '58c60587-9559-4747-a7bc-a90d36147caa'
    and new.document_id = 'disociados-editable-fiel-v1'
    and jsonb_typeof(new.data->'html') = 'string'
    and length(new.data->>'html') > 0 then
  insert into public.disociados_publication(id,data,updated_at)
  values ('disociados', jsonb_build_object(
   'html',new.data->>'html',
   'coverTitle',new.data->>'coverTitle',
   'coverSynopsis',new.data->>'coverSynopsis',
   'titleSpacing',new.data->'titleSpacing',
   'chapterSpacing',new.data->'chapterSpacing',
   'textSpacing',new.data->'textSpacing'
  ), clock_timestamp())
  on conflict(id) do update set data=excluded.data,updated_at=excluded.updated_at;
 end if;
 return new;
end;
$$;
revoke all on function public.sync_disociados_publication() from public, anon, authenticated;
drop trigger if exists sync_disociados_publication on public.kairos_documents;
create trigger sync_disociados_publication after insert or update of data on public.kairos_documents
 for each row execute function public.sync_disociados_publication();
insert into public.disociados_publication(id,data,updated_at)
select 'disociados',jsonb_build_object(
 'html',data->>'html','coverTitle',data->>'coverTitle','coverSynopsis',data->>'coverSynopsis',
 'titleSpacing',data->'titleSpacing','chapterSpacing',data->'chapterSpacing','textSpacing',data->'textSpacing'
),clock_timestamp()
from public.kairos_documents
where user_id::text='58c60587-9559-4747-a7bc-a90d36147caa'
 and document_id='disociados-editable-fiel-v1'
 and jsonb_typeof(data->'html')='string' and length(data->>'html')>0
on conflict(id) do update set data=excluded.data,updated_at=excluded.updated_at;
commit;
