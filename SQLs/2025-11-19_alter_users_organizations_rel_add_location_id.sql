-- Agregar campo location_id a users_organizations_rel
ALTER TABLE public.users_organizations_rel
ADD COLUMN location_id uuid NULL;

-- Opcional: agregar FK si quieres integridad referencial
ALTER TABLE public.users_organizations_rel
ADD CONSTRAINT users_organizations_rel_location_id_fkey FOREIGN KEY (location_id)
REFERENCES public.locations(id) ON DELETE SET NULL;
