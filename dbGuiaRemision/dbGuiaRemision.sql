-- ============================================================
--  DATOS DE PRUEBA - SISTEMA DE GUÍAS DE REMISIÓN
--  Ejecutar DESPUÉS de guia_remision_db.sql
-- ============================================================

SET search_path = guia, public;

-- ============================================================
--  1. UBIGEOS (muestra representativa del Perú)
-- ============================================================
INSERT INTO guia.ubigeo (codigo, departamento, provincia, distrito) VALUES
('150101', 'LIMA',      'LIMA',      'LIMA'),
('150102', 'LIMA',      'LIMA',      'ANCÓN'),
('150130', 'LIMA',      'LIMA',      'SAN ISIDRO'),
('150131', 'LIMA',      'LIMA',      'SAN MIGUEL'),
('150140', 'LIMA',      'LIMA',      'SURCO'),
('040101', 'AREQUIPA',  'AREQUIPA',  'AREQUIPA'),
('040102', 'AREQUIPA',  'AREQUIPA',  'ALTO SELVA ALEGRE'),
('130101', 'LA LIBERTAD','TRUJILLO', 'TRUJILLO'),
('060101', 'CAJAMARCA', 'CAJAMARCA', 'CAJAMARCA'),
('080101', 'CUSCO',     'CUSCO',     'CUSCO'),
('200101', 'PIURA',     'PIURA',     'PIURA'),
('140101', 'LAMBAYEQUE','CHICLAYO',  'CHICLAYO');

-- ============================================================
--  2. EMPRESA EMISORA
-- ============================================================
INSERT INTO guia.empresa (
    id, ruc, razon_social, nombre_comercial,
    direccion_fiscal, ubigeo_id, telefono, email,
    sol_usuario, activo
) VALUES (
    '01000000-0000-0000-0000-000000000001',
    '20601234567',
    'DISTRIBUIDORA ANDINA S.A.C.',
    'DIST. ANDINA',
    'AV. INDUSTRIAL 1234, LIMA',
    '150101',
    '01-4567890',
    'operaciones@distribandina.com.pe',
    'DISTRANDINA',
    TRUE
);

-- ============================================================
--  3. ESTABLECIMIENTOS
-- ============================================================
INSERT INTO guia.establecimiento (
    id, empresa_id, codigo, denominacion, direccion, ubigeo_id, es_principal
) VALUES
(
    '02000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    '0000', 'SEDE PRINCIPAL - LIMA',
    'AV. INDUSTRIAL 1234, LIMA', '150101', TRUE
),
(
    '02000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    '0001', 'SUCURSAL AREQUIPA',
    'CALLE MERCADERES 456, AREQUIPA', '040101', FALSE
);

-- ============================================================
--  4. SERIES DE DOCUMENTOS
-- ============================================================
INSERT INTO guia.serie_documento (
    establecimiento_id, tipo_doc, serie, correlativo_actual
) VALUES
('02000000-0000-0000-0000-000000000001', 'T09', 'T001', 3),
('02000000-0000-0000-0000-000000000001', 'T09', 'T002', 0),
('02000000-0000-0000-0000-000000000002', 'T09', 'T003', 1);

-- ============================================================
--  5. PERSONAS (clientes / destinatarios / remitentes)
-- ============================================================
INSERT INTO guia.persona (
    id, empresa_id, tipo_doc, num_doc, razon_social,
    direccion, ubigeo_id, telefono, email, es_cliente, es_proveedor
) VALUES
-- Clientes empresa (RUC)
(
    '03000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    '6', '20512345678', 'SUPERMERCADOS EL VALLE S.A.',
    'AV. JAVIER PRADO 3456, SAN ISIDRO', '150130',
    '01-2223333', 'compras@elvalle.com.pe', TRUE, FALSE
),
(
    '03000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    '6', '20498765432', 'COMERCIAL DEL SUR E.I.R.L.',
    'CALLE MERCADERES 789, AREQUIPA', '040101',
    '054-223344', 'logistica@comdelsur.pe', TRUE, FALSE
),
(
    '03000000-0000-0000-0000-000000000003',
    '01000000-0000-0000-0000-000000000001',
    '6', '20601234567', 'DISTRIBUIDORA ANDINA S.A.C.',
    'AV. INDUSTRIAL 1234, LIMA', '150101',
    '01-4567890', 'operaciones@distribandina.com.pe', FALSE, FALSE
);

-- Persona natural (DNI)
INSERT INTO guia.persona (
    id, empresa_id, tipo_doc, num_doc,
    nombre, apellido_paterno, apellido_materno,
    direccion, ubigeo_id, telefono, email,
    es_cliente, es_proveedor
) VALUES (
    '03000000-0000-0000-0000-000000000004',
    '01000000-0000-0000-0000-000000000001',
    '1', '43215678',
    'JORGE', 'GARCIA', 'TORRES',
    'JR. LOS PINOS 234, SAN MIGUEL', '150131',
    '987654321', 'jgarcia@gmail.com',
    TRUE, FALSE
);

-- ============================================================
--  6. VEHICULOS
-- ============================================================
INSERT INTO guia.vehiculo (
    id, empresa_id, marca, modelo, placa, anio, color
) VALUES
(
    '05000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    'MERCEDES BENZ', 'ATEGO 1725', 'ABC-123', 2020, 'BLANCO'
),
(
    '05000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    'VOLVO', 'FH 420', 'XYZ-456', 2019, 'GRIS'
),
(
    '05000000-0000-0000-0000-000000000003',
    '01000000-0000-0000-0000-000000000001',
    'TOYOTA', 'HILUX', 'DEF-789', 2022, 'PLATA'
);

-- ============================================================
--  7. CONDUCTORES (primero insertar personas naturales)
-- ============================================================
INSERT INTO guia.persona (
    id, empresa_id, tipo_doc, num_doc,
    nombre, apellido_paterno, apellido_materno,
    direccion, ubigeo_id, telefono, activo
) VALUES
(
    '04000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    '1', '09876543',
    'CARLOS', 'MENDOZA', 'QUISPE',
    'AV. LOS ALAMOS 567, LIMA', '150101', '991122334', TRUE
),
(
    '04000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    '1', '12398765',
    'LUIS', 'HUANCA', 'FLORES',
    'JR. UNION 890, LIMA', '150101', '962233445', TRUE
),
(
    '04000000-0000-0000-0000-000000000003',
    '01000000-0000-0000-0000-000000000001',
    '1', '56781234',
    'MARIA', 'CCOPA', 'MAMANI',
    'CALLE REAL 123, AREQUIPA', '040101', '954433221', TRUE
);

INSERT INTO guia.conductor (
    id, persona_id, empresa_id,
    licencia_tipo, licencia_numero, licencia_vencimiento
) VALUES
(
    '06000000-0000-0000-0000-000000000001',
    '04000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    'A3', 'Q09876543', '2026-12-31'
),
(
    '06000000-0000-0000-0000-000000000002',
    '04000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    'A2', 'Q12398765', '2025-08-15'
),
(
    '06000000-0000-0000-0000-000000000003',
    '04000000-0000-0000-0000-000000000003',
    '01000000-0000-0000-0000-000000000001',
    'B2C', 'Q56781234', '2027-03-20'
);

-- ============================================================
--  8. USUARIOS
-- ============================================================
INSERT INTO guia.usuario (
    id, empresa_id, nombre_completo, email,
    password_hash, rol
) VALUES
(
    '08000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    'ADMINISTRADOR DEL SISTEMA',
    'admin@distribandina.com.pe',
    '$2b$12$HASH_EJEMPLO_ADMIN_NO_USAR_EN_PROD',
    'ADMIN'
),
(
    '08000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    'ANA LUCIA VARGAS ROMERO',
    'avargas@distribandina.com.pe',
    '$2b$12$HASH_EJEMPLO_OPERADOR_NO_USAR_EN_PROD',
    'OPERADOR'
),
(
    '08000000-0000-0000-0000-000000000003',
    '01000000-0000-0000-0000-000000000001',
    'PEDRO SALAS QUISPE',
    'psalas@distribandina.com.pe',
    '$2b$12$HASH_EJEMPLO_SUPERVISOR_NO_USAR_EN_PROD',
    'SUPERVISOR'
);

-- ============================================================
--  9. GUÍAS DE REMISIÓN
-- ============================================================

-- GUÍA 1: Lima → Arequipa, transporte privado, venta (ACEPTADA)
INSERT INTO guia.guia_remision (
    id, empresa_id, establecimiento_id,
    serie, correlativo,
    fecha_emision, fecha_inicio_traslado,
    motivo_traslado, modalidad_transporte,
    remitente_id, destinatario_id,
    direccion_partida, ubigeo_partida,
    direccion_llegada, ubigeo_llegada,
    peso_bruto_total, unidad_peso, num_bultos,
    estado, usuario_id
) VALUES (
    '07000000-0000-0000-0000-000000000001',
    '01000000-0000-0000-0000-000000000001',
    '02000000-0000-0000-0000-000000000001',
    'T001', '00000001',
    '2026-05-10', '2026-05-11',
    '01', '02',
    '03000000-0000-0000-0000-000000000003',
    '03000000-0000-0000-0000-000000000002',
    'AV. INDUSTRIAL 1234, LIMA', '150101',
    'CALLE MERCADERES 789, AREQUIPA', '040101',
    1250.500, 'KGM', 48,
    'ACEPTADA',
    '08000000-0000-0000-0000-000000000002'
);

-- GUÍA 2: Lima → Lima (traslado entre establecimientos, EMITIDA)
INSERT INTO guia.guia_remision (
    id, empresa_id, establecimiento_id,
    serie, correlativo,
    fecha_emision, fecha_inicio_traslado,
    motivo_traslado, modalidad_transporte,
    remitente_id, destinatario_id,
    direccion_partida, ubigeo_partida,
    direccion_llegada, ubigeo_llegada,
    peso_bruto_total, unidad_peso, num_bultos,
    estado, observaciones, usuario_id
) VALUES (
    '07000000-0000-0000-0000-000000000002',
    '01000000-0000-0000-0000-000000000001',
    '02000000-0000-0000-0000-000000000001',
    'T001', '00000002',
    '2026-05-20', '2026-05-20',
    '04', '02',
    '03000000-0000-0000-0000-000000000003',
    '03000000-0000-0000-0000-000000000001',
    'AV. INDUSTRIAL 1234, LIMA', '150101',
    'AV. JAVIER PRADO 3456, SAN ISIDRO', '150130',
    380.000, 'KGM', 15,
    'EMITIDA',
    'Reposición de stock urgente para campaña',
    '08000000-0000-0000-0000-000000000002'
);

-- GUÍA 3: Lima → Trujillo, transporte público (ENVIADA_SUNAT)
INSERT INTO guia.guia_remision (
    id, empresa_id, establecimiento_id,
    serie, correlativo,
    fecha_emision, fecha_inicio_traslado,
    motivo_traslado, modalidad_transporte,
    remitente_id, destinatario_id,
    direccion_partida, ubigeo_partida,
    direccion_llegada, ubigeo_llegada,
    peso_bruto_total, unidad_peso, num_bultos,
    estado, usuario_id
) VALUES (
    '07000000-0000-0000-0000-000000000003',
    '01000000-0000-0000-0000-000000000001',
    '02000000-0000-0000-0000-000000000001',
    'T001', '00000003',
    '2026-06-01', '2026-06-02',
    '01', '01',
    '03000000-0000-0000-0000-000000000003',
    '03000000-0000-0000-0000-000000000001',
    'AV. INDUSTRIAL 1234, LIMA', '150101',
    'AV. AMERICA SUR 1800, TRUJILLO', '130101',
    2100.750, 'KGM', 90,
    'ENVIADA_SUNAT',
    '08000000-0000-0000-0000-000000000003'
);

-- ============================================================
--  10. DETALLE DE GUÍAS
-- ============================================================

-- Detalle guía 1
INSERT INTO guia.guia_detalle (
    guia_id, linea, codigo_producto, descripcion,
    cantidad, unidad_medida, peso_unitario
) VALUES
('07000000-0000-0000-0000-000000000001', 1, 'PROD-001', 'ACEITE VEGETAL BOTELLA 1L',         200, 'NIU', 1.050),
('07000000-0000-0000-0000-000000000001', 2, 'PROD-002', 'HARINA DE TRIGO BOLSA 50KG',         15, 'NIU', 50.000),
('07000000-0000-0000-0000-000000000001', 3, 'PROD-003', 'AZUCAR RUBIA BOLSA 50KG',            10, 'NIU', 50.000),
('07000000-0000-0000-0000-000000000001', 4, 'PROD-004', 'LECHE EVAPORADA CAJA X 48 UNIDADES',  3, 'ZA', 29.000);

-- Detalle guía 2
INSERT INTO guia.guia_detalle (
    guia_id, linea, codigo_producto, descripcion,
    cantidad, unidad_medida, peso_unitario
) VALUES
('07000000-0000-0000-0000-000000000002', 1, 'PROD-005', 'FIDEOS SPAGHETTI BOLSA 500G', 300, 'NIU', 0.520),
('07000000-0000-0000-0000-000000000002', 2, 'PROD-006', 'ARROZ EXTRA BOLSA 5KG',        50, 'NIU', 5.050),
('07000000-0000-0000-0000-000000000002', 3, 'PROD-001', 'ACEITE VEGETAL BOTELLA 1L',     72, 'NIU', 1.050);

-- Detalle guía 3
INSERT INTO guia.guia_detalle (
    guia_id, linea, codigo_producto, descripcion,
    cantidad, unidad_medida, peso_unitario, lote, fecha_vencimiento
) VALUES
('07000000-0000-0000-0000-000000000003', 1, 'PROD-007', 'CONSERVA DE ATUN 170G',  500, 'NIU', 0.210, 'L2024-05', '2027-05-31'),
('07000000-0000-0000-0000-000000000003', 2, 'PROD-008', 'MAYONESA 500G',           200, 'NIU', 0.550, 'L2024-04', '2026-10-15'),
('07000000-0000-0000-0000-000000000003', 3, 'PROD-009', 'SALSA DE TOMATE 400G',    400, 'NIU', 0.430, 'L2024-04', '2026-09-30'),
('07000000-0000-0000-0000-000000000003', 4, 'PROD-010', 'GALLETAS SODA CAJA 24UN', 120, 'ZA', 0.850, NULL,       NULL);

-- ============================================================
--  11. TRANSPORTISTAS DE GUÍAS
-- ============================================================

-- Guía 1: transportista propio (vehículo + conductor registrados)
INSERT INTO guia.guia_transportista (
    guia_id, vehiculo_id, conductor_id
) VALUES (
    '07000000-0000-0000-0000-000000000001',
    '05000000-0000-0000-0000-000000000001',
    '06000000-0000-0000-0000-000000000001'
);

-- Guía 2: transportista propio
INSERT INTO guia.guia_transportista (
    guia_id, vehiculo_id, conductor_id
) VALUES (
    '07000000-0000-0000-0000-000000000002',
    '05000000-0000-0000-0000-000000000003',
    '06000000-0000-0000-0000-000000000003'
);

-- Guía 3: transportista externo (datos manuales)
INSERT INTO guia.guia_transportista (
    guia_id,
    ruc_transportista, razon_social_transportista,
    placa_manual, licencia_manual,
    tipo_doc_conductor, num_doc_conductor, nombre_conductor
) VALUES (
    '07000000-0000-0000-0000-000000000003',
    '20301234567', 'TRANSPORTES NORTE PERUANO S.A.',
    'T4U-956', 'Q44556677',
    '1', '44556677', 'ROBERTO CASTILLO VEGA'
);

-- ============================================================
--  12. DOCUMENTOS DE REFERENCIA
-- ============================================================
INSERT INTO guia.guia_referencia (
    guia_id, tipo_doc, serie, correlativo, fecha_emision
) VALUES
-- Guía 1 referencia a factura de venta
('07000000-0000-0000-0000-000000000001', '01', 'F001', '00001234', '2026-05-10'),
-- Guía 2 referencia a orden interna
('07000000-0000-0000-0000-000000000002', '01', 'F001', '00001240', '2026-05-20'),
-- Guía 3 referencia a dos facturas
('07000000-0000-0000-0000-000000000003', '01', 'F001', '00001255', '2026-06-01'),
('07000000-0000-0000-0000-000000000003', '01', 'F001', '00001256', '2026-06-01');

-- ============================================================
--  CONSULTAS DE VERIFICACIÓN
-- ============================================================

-- Ver todas las guías con info completa
SELECT
    numero_completo,
    fecha_emision,
    fecha_inicio_traslado,
    motivo_traslado,
    remitente,
    destinatario,
    punto_partida,
    punto_llegada,
    peso_bruto_total || ' ' || unidad_peso AS peso,
    num_bultos,
    num_items,
    estado
FROM guia.v_guias
ORDER BY fecha_emision;

-- Ver detalle de guía 1
SELECT
    linea,
    codigo_producto,
    descripcion,
    cantidad,
    unidad_medida,
    peso_unitario,
    peso_total
FROM guia.guia_detalle
WHERE guia_id = '07000000-0000-0000-0000-000000000001'
ORDER BY linea;

-- Resumen de guías por estado
SELECT estado, COUNT(*) AS total, SUM(peso_bruto_total) AS peso_total_kg
FROM guia.guia_remision
GROUP BY estado
ORDER BY estado;

-- Conductores con licencia por vencer
SELECT * FROM guia.v_conductores_licencia_por_vencer;

-- Buscar persona por nombre (full-text search)
SELECT num_doc, razon_social, nombre, apellido_paterno
FROM guia.persona
WHERE ts_busqueda @@ to_tsquery('simple', guia.immutable_unaccent('comercial'));

SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'guia';

SELECT schema_name
FROM information_schema.schemata
WHERE schema_name = 'guia';