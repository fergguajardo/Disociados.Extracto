-- INSTALACION INICIAL: ejecutar una sola vez en el SQL Editor de Supabase.
-- No elimina ni reemplaza objetos existentes. Si encuentra nombres ocupados,
-- se detiene; no continuar sin revisar el error.
-- Cada guardado de Editable publica su contenido, titulo y sinopsis.
-- La tabla original kairos_documents conserva sus datos y permisos.
-- Publica exclusivamente Disociados; no habilita la lectura de kairos_documents.
begin;
do $preflight$
begin
 if pg_catalog.to_regclass('public.kairos_documents') is null then
  raise exception 'No existe public.kairos_documents. No se instalo la sincronizacion.';
 end if;
 if pg_catalog.to_regclass('public.disociados_publication') is not null
    or exists(select 1 from pg_catalog.pg_proc p join pg_catalog.pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='sync_disociados_publication')
    or exists(select 1 from pg_catalog.pg_trigger where tgrelid=pg_catalog.to_regclass('public.kairos_documents') and tgname='sync_disociados_publication') then
  raise exception 'Ya existen objetos de publicacion. Se cancelo sin reemplazarlos. Revisar la configuracion existente antes de continuar.';
 end if;
 if not exists(select 1 from public.kairos_documents
   where user_id::text='58c60587-9559-4747-a7bc-a90d36147caa'
   and document_id='disociados-editable-fiel-v1'
   and jsonb_typeof(data->'html')='string' and length(data->>'html')>0) then
  raise exception 'No se encontro Editable guardado en Supabase. No se instalo la sincronizacion.';
 end if;
end;
$preflight$;
create table public.disociados_publication (
 id text primary key check (id = 'disociados'),
 data jsonb not null,
 updated_at timestamptz not null default now()
);
alter table public.disociados_publication enable row level security;
revoke all on public.disociados_publication from public, anon, authenticated;
grant select on public.disociados_publication to anon, authenticated;
create policy "Lectura publica de Disociados" on public.disociados_publication
 for select to anon, authenticated using (id = 'disociados');
create function public.sync_disociados_publication()
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
;
-- Verificacion: debe devolver una fila y mostrar RLS habilitado.
select p.id, p.updated_at, length(p.data->>'html') as caracteres_publicados,
 c.relrowsecurity as rls_habilitado
from public.disociados_publication p
join pg_catalog.pg_class c on c.oid='public.disociados_publication'::regclass;
commit;
