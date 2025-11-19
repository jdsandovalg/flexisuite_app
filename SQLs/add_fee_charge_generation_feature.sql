-- Agregar feature para la generación de cargos de cuotas
-- Feature: cuota_generar_cargo
-- Rol: Admin
-- Disponible para todos los planes

-- 1. Insertar el feature en la tabla features
INSERT INTO public.features (code, description, parent_module, is_menu_item, icon_name)
VALUES (
    'cuota_generar_cargo',
    'feeChargeGeneration.title',
    'cuotas',
    true,
    'add_card'
)
ON CONFLICT (code) DO UPDATE
SET 
    description = EXCLUDED.description,
    parent_module = EXCLUDED.parent_module,
    is_menu_item = EXCLUDED.is_menu_item,
    icon_name = EXCLUDED.icon_name;

-- 2. Asignar el feature a todos los planes existentes para el rol 'admin'
-- Plan IDs conocidos:
-- - 92e872a1-7f1d-4928-b445-f8fb983b0fcb (Plan Básico)
-- - 433fafda-7270-4686-8c42-b76e4c3401c0 (Plan Intermedio)
-- - 37b50079-2d2a-40b5-8b7a-b8c80a29d1a0 (Plan Premium)

INSERT INTO public.plan_features (plan_id, feature_code, value, role)
VALUES 
    ('92e872a1-7f1d-4928-b445-f8fb983b0fcb', 'cuota_generar_cargo', 'unlocked', 'admin'),
    ('433fafda-7270-4686-8c42-b76e4c3401c0', 'cuota_generar_cargo', 'unlocked', 'admin'),
    ('37b50079-2d2a-40b5-8b7a-b8c80a29d1a0', 'cuota_generar_cargo', 'unlocked', 'admin')
ON CONFLICT (plan_id, feature_code) DO UPDATE
SET 
    value = EXCLUDED.value,
    role = EXCLUDED.role;

-- Verificación: Ver los features de cuotas para admin
-- SELECT pf.*, f.description, f.icon_name 
-- FROM public.plan_features pf
-- JOIN public.features f ON f.code = pf.feature_code
-- WHERE pf.feature_code LIKE 'cuota%' AND pf.role = 'admin'
-- ORDER BY pf.plan_id, pf.feature_code;
