-- ============================================================
--  SISTEMA DE GUÍAS DE REMISIÓN ELECTRÓNICA
--  PostgreSQL 15+ — Versión 3.0 (Nomenclatura MAE_/TRS_/LOG_)
--  Conforme a: SUNAT RS N° 000114-2022 / UBL 2.1
--
--  Convenciones:
--    • Prefijo  MAE_   → tablas maestras (catálogos, datos de referencia)
--    • Prefijo  TRS_   → tablas transaccionales (documentos, operaciones)
--    • Prefijo  LOG_   → tablas de auditoría / historial
--    • Prefijos fn_      → funciones de dominio
--              sp_      → procedimientos de negocio
--              v_       → vistas de consulta
--              idx_     → índices
--              pk_ uq_ fk_ ck_ → constraints
--    • Todas las tablas viven en el esquema public (sin esquemas separados)
-- ============================================================

-- ============================================================
--  0.  EXTENSIONES
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";      -- gen_random_uuid(), pgp_sym_encrypt
CREATE EXTENSION IF NOT EXISTS "unaccent";       -- normalización de texto

-- ============================================================
--  1.  FUNCIÓN AUXILIAR INMUTABLE (requerida para columnas GENERATED)
-- ============================================================
CREATE OR REPLACE FUNCTION fn_unaccent_immutable(p_texto TEXT)
RETURNS TEXT
LANGUAGE sql IMMUTABLE PARALLEL SAFE STRICT
AS $$
    SELECT unaccent(p_texto);
$$;

COMMENT ON FUNCTION fn_unaccent_immutable(TEXT) IS
    'Wrapper IMMUTABLE sobre unaccent(), necesario para índices funcionales y columnas generadas.';

-- ============================================================
--  2.  TIPOS ENUMERADOS
-- ============================================================

-- Documentos de identidad según catálogo SUNAT N° 6
CREATE TYPE tipo_documento_identidad AS ENUM (
    '1',   -- DNI
    '4',   -- Carnet de extranjería
    '6',   -- RUC
    '7',   -- Pasaporte
    'A'    -- Cédula diplomática de identidad
);

-- Catálogo N° 18 — Modalidad de traslado
CREATE TYPE modalidad_transporte AS ENUM (
    '01',  -- Transporte público
    '02'   -- Transporte privado
);

-- Catálogo N° 20 — Motivo de traslado
CREATE TYPE motivo_traslado AS ENUM (
    '01',  -- Venta
    '02',  -- Compra
    '04',  -- Traslado entre establecimientos propios
    '08',  -- Importación
    '09',  -- Exportación
    '13',  -- Otros
    '14',  -- Venta sujeta a confirmación del comprador
    '17',  -- Traslado de bienes para transformación
    '18',  -- Traslado emisor itinerante CP
    '19'   -- Traslado a zona primaria
);

-- Estado del ciclo de vida de la guía
CREATE TYPE estado_guia AS ENUM (
    'BORRADOR',
    'EMITIDA',
    'ENVIADA_SUNAT',
    'ACEPTADA',
    'RECHAZADA',
    'ANULADA',
    'BAJA'
);

-- Roles de acceso al sistema
CREATE TYPE rol_usuario AS ENUM (
    'ADMIN',
    'SUPERVISOR',
    'OPERADOR',
    'CONSULTA'
);

-- Catálogo N° 3 — Unidades de peso
CREATE TYPE unidad_peso AS ENUM (
    'KGM',  -- Kilogramo
    'TNE',  -- Tonelada métrica
    'GRM',  -- Gramo
    'LBR'   -- Libra
);

-- Tipos de documento de referencia
CREATE TYPE tipo_doc_referencia AS ENUM (
    '01',  -- Factura electrónica
    '03',  -- Boleta de venta electrónica
    '04',  -- Liquidación de compra
    '07',  -- Nota de crédito electrónica
    '08',  -- Nota de débito electrónica
    '09',  -- Guía de remisión — Remitente
    '31',  -- Guía de remisión — Transportista
    'NE'   -- Nota de entrada al almacén
);

-- ============================================================
--  3.  TABLAS MAESTRAS (MAE_)
-- ============================================================

-- ------------------------------------------------------------
--  3.1  MAE_UBIGEO  (INEI — padrón de ubigeos del Perú)
-- ------------------------------------------------------------
CREATE TABLE MAE_UBIGEO (
    id              CHAR(6)         NOT NULL,
    departamento    VARCHAR(100)    NOT NULL,
    provincia       VARCHAR(100)    NOT NULL,
    distrito        VARCHAR(100)    NOT NULL,
    codigo_postal   VARCHAR(10),
    CONSTRAINT pk_mae_ubigeo
        PRIMARY KEY (id),
    CONSTRAINT ck_mae_ubigeo_codigo
        CHECK (id ~ '^\d{6}$')
);

COMMENT ON TABLE  MAE_UBIGEO              IS 'Catálogo de ubigeos del Perú según INEI (formato DDPPDD).';
COMMENT ON COLUMN MAE_UBIGEO.id           IS 'Código de 6 dígitos: 2 dpto + 2 prov + 2 distrito.';
COMMENT ON COLUMN MAE_UBIGEO.departamento IS 'Nombre del departamento / región.';
COMMENT ON COLUMN MAE_UBIGEO.provincia    IS 'Nombre de la provincia.';
COMMENT ON COLUMN MAE_UBIGEO.distrito     IS 'Nombre del distrito.';
COMMENT ON COLUMN MAE_UBIGEO.codigo_postal IS 'Código postal (opcional).';

CREATE INDEX idx_mae_ubigeo_dpto ON MAE_UBIGEO (departamento);
CREATE INDEX idx_mae_ubigeo_completo ON MAE_UBIGEO (departamento, provincia, distrito);

-- ------------------------------------------------------------
--  3.2  MAE_EMPRESA  (emisor de las guías)
-- ------------------------------------------------------------
CREATE TABLE MAE_EMPRESA (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    ruc                 CHAR(11)        NOT NULL,
    razon_social        VARCHAR(200)    NOT NULL,
    nombre_comercial    VARCHAR(200),
    direccion_fiscal    VARCHAR(300)    NOT NULL,
    id_mae_ubigeo       CHAR(6)         NOT NULL,
    telefono            VARCHAR(20),
    email               VARCHAR(150),
    logo_url            VARCHAR(500),
    -- Credenciales SOL — almacenar cifradas en capa de aplicación;
    -- los campos _enc contienen el valor cifrado (AES-256-GCM)
    sol_usuario         VARCHAR(20),
    sol_password_enc    VARCHAR(500),
    cert_digital_path   VARCHAR(500),
    cert_password_enc   VARCHAR(500),
    activo              BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_empresa
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_empresa_ruc
        UNIQUE (ruc),
    CONSTRAINT fk_mae_empresa_ubigeo
        FOREIGN KEY (id_mae_ubigeo) REFERENCES MAE_UBIGEO (id),
    CONSTRAINT ck_mae_empresa_ruc
        CHECK (ruc ~ '^\d{11}$'),
    CONSTRAINT ck_mae_empresa_email
        CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' OR email IS NULL)
);

COMMENT ON TABLE  MAE_EMPRESA                  IS 'Empresas habilitadas para emitir guías de remisión electrónicas.';
COMMENT ON COLUMN MAE_EMPRESA.ruc              IS 'RUC de 11 dígitos (SUNAT).';
COMMENT ON COLUMN MAE_EMPRESA.sol_password_enc IS 'Contraseña SOL cifrada con AES-256-GCM. La capa de aplicación gestiona el descifrado.';
COMMENT ON COLUMN MAE_EMPRESA.cert_password_enc IS 'Passphrase del certificado digital, cifrada.';

CREATE INDEX idx_mae_empresa_activo ON MAE_EMPRESA (activo) WHERE activo;

-- ------------------------------------------------------------
--  3.3  MAE_ESTABLECIMIENTO  (puntos de operación SUNAT)
-- ------------------------------------------------------------
CREATE TABLE MAE_ESTABLECIMIENTO (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_mae_empresa  UUID            NOT NULL,
    codigo          VARCHAR(4)      NOT NULL,
    denominacion    VARCHAR(200)    NOT NULL,
    direccion       VARCHAR(300)    NOT NULL,
    id_mae_ubigeo   CHAR(6)         NOT NULL,
    telefono        VARCHAR(20),
    email           VARCHAR(150),
    es_principal    BOOLEAN         NOT NULL DEFAULT FALSE,
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_establecimiento
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_establecimiento_codigo
        UNIQUE (id_mae_empresa, codigo),
    CONSTRAINT fk_mae_establecimiento_empresa
        FOREIGN KEY (id_mae_empresa) REFERENCES MAE_EMPRESA (id),
    CONSTRAINT fk_mae_establecimiento_ubigeo
        FOREIGN KEY (id_mae_ubigeo)  REFERENCES MAE_UBIGEO (id),
    CONSTRAINT ck_mae_establecimiento_codigo
        CHECK (codigo ~ '^\d{4}$')
);

COMMENT ON TABLE  MAE_ESTABLECIMIENTO          IS 'Establecimientos / puntos de venta registrados ante SUNAT.';
COMMENT ON COLUMN MAE_ESTABLECIMIENTO.codigo   IS 'Código de 4 dígitos asignado por SUNAT (ej: 0000 = casa matriz).';
COMMENT ON COLUMN MAE_ESTABLECIMIENTO.es_principal IS 'TRUE = establecimiento principal (casa matriz).';

CREATE INDEX idx_mae_establecimiento_empresa ON MAE_ESTABLECIMIENTO (id_mae_empresa);
CREATE INDEX idx_mae_establecimiento_activo  ON MAE_ESTABLECIMIENTO (id_mae_empresa, activo);

-- ------------------------------------------------------------
--  3.4  MAE_PERSONA  (remitentes, destinatarios, proveedores, clientes)
-- ------------------------------------------------------------
CREATE TABLE MAE_PERSONA (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_mae_empresa      UUID,                         -- NULL → persona global / inter-empresas
    tipo_doc            tipo_documento_identidad NOT NULL DEFAULT '6',
    num_doc             VARCHAR(20)     NOT NULL,
    razon_social        VARCHAR(200),                 -- Para personas jurídicas (RUC)
    nombre              VARCHAR(100),                 -- Para personas naturales
    apellido_paterno    VARCHAR(100),
    apellido_materno    VARCHAR(100),
    direccion           VARCHAR(300),
    id_mae_ubigeo       CHAR(6),
    telefono            VARCHAR(20),
    email               VARCHAR(150),
    es_cliente          BOOLEAN         NOT NULL DEFAULT FALSE,
    es_proveedor        BOOLEAN         NOT NULL DEFAULT FALSE,
    activo              BOOLEAN         NOT NULL DEFAULT TRUE,
    -- Columna generada para full-text search (solo funciones IMMUTABLE)
    ts_busqueda         TSVECTOR GENERATED ALWAYS AS (
                            to_tsvector('simple',
                                fn_unaccent_immutable(
                                    COALESCE(razon_social,       '') || ' ' ||
                                    COALESCE(nombre,             '') || ' ' ||
                                    COALESCE(apellido_paterno,   '') || ' ' ||
                                    COALESCE(apellido_materno,   '') || ' ' ||
                                    COALESCE(num_doc,            '')
                                )
                            )
                        ) STORED,
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_persona
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_persona_doc
        UNIQUE (tipo_doc, num_doc, id_mae_empresa),
    CONSTRAINT fk_mae_persona_empresa
        FOREIGN KEY (id_mae_empresa) REFERENCES MAE_EMPRESA (id),
    CONSTRAINT fk_mae_persona_ubigeo
        FOREIGN KEY (id_mae_ubigeo)  REFERENCES MAE_UBIGEO (id),
    -- Persona jurídica: requiere razon_social; natural: nombre + apellido paterno
    CONSTRAINT ck_mae_persona_identificacion CHECK (
        (tipo_doc = '6' AND razon_social IS NOT NULL)
        OR
        (tipo_doc <> '6' AND nombre IS NOT NULL AND apellido_paterno IS NOT NULL)
    )
);

COMMENT ON TABLE  MAE_PERSONA IS
    'Personas naturales y jurídicas: clientes, proveedores, remitentes y destinatarios.';
COMMENT ON COLUMN MAE_PERSONA.ts_busqueda IS
    'Vector full-text generado automáticamente a partir de nombre/razón social y documento.';
COMMENT ON COLUMN MAE_PERSONA.id_mae_empresa IS
    'NULL indica persona compartida entre todas las empresas del sistema.';

CREATE INDEX idx_mae_persona_empresa  ON MAE_PERSONA (id_mae_empresa);
CREATE INDEX idx_mae_persona_num_doc  ON MAE_PERSONA (num_doc);
CREATE INDEX idx_mae_persona_fts      ON MAE_PERSONA USING gin (ts_busqueda);

-- ------------------------------------------------------------
--  3.5  MAE_VEHICULO
-- ------------------------------------------------------------
CREATE TABLE MAE_VEHICULO (
    id              UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_mae_empresa  UUID            NOT NULL,
    marca           VARCHAR(50)     NOT NULL,
    modelo          VARCHAR(100),
    placa           VARCHAR(10)     NOT NULL,
    anio            SMALLINT,
    color           VARCHAR(30),
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_vehiculo
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_vehiculo_placa
        UNIQUE (id_mae_empresa, placa),
    CONSTRAINT fk_mae_vehiculo_empresa
        FOREIGN KEY (id_mae_empresa) REFERENCES MAE_EMPRESA (id),
    CONSTRAINT ck_mae_vehiculo_placa
        CHECK (placa ~ '^[A-Z0-9\-]{3,10}$'),
    CONSTRAINT ck_mae_vehiculo_anio
        CHECK (anio BETWEEN 1950 AND 2100)
);

COMMENT ON TABLE  MAE_VEHICULO       IS 'Vehículos registrados para el traslado de mercadería.';
COMMENT ON COLUMN MAE_VEHICULO.placa IS 'Placa vehicular — formatos: ABC-123 (antiguo) o A1B234 (nuevo).';

CREATE INDEX idx_mae_vehiculo_empresa ON MAE_VEHICULO (id_mae_empresa, activo);

-- ------------------------------------------------------------
--  3.6  MAE_CONDUCTOR
-- ------------------------------------------------------------
CREATE TABLE MAE_CONDUCTOR (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_mae_persona          UUID            NOT NULL,
    id_mae_empresa          UUID,
    licencia_tipo           VARCHAR(5)      NOT NULL,
    licencia_numero         VARCHAR(20)     NOT NULL,
    licencia_vencimiento    DATE            NOT NULL,
    activo                  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_conductor
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_conductor_licencia
        UNIQUE (licencia_numero),
    CONSTRAINT fk_mae_conductor_persona
        FOREIGN KEY (id_mae_persona)  REFERENCES MAE_PERSONA (id),
    CONSTRAINT fk_mae_conductor_empresa
        FOREIGN KEY (id_mae_empresa)  REFERENCES MAE_EMPRESA (id),
    CONSTRAINT ck_mae_conductor_licencia_tipo
        CHECK (licencia_tipo ~ '^(A1|A2a|A2b|A3a|A3b|B1|B2a|B2b|B2c|C)$')
);

COMMENT ON TABLE  MAE_CONDUCTOR                     IS 'Conductores habilitados para transporte de carga.';
COMMENT ON COLUMN MAE_CONDUCTOR.licencia_tipo       IS 'Categoría MTC (A1, A2a, A2b, A3a, A3b, B2c, etc.).';
COMMENT ON COLUMN MAE_CONDUCTOR.licencia_vencimiento IS 'Fecha de vencimiento de la licencia de conducir.';

CREATE INDEX idx_mae_conductor_empresa       ON MAE_CONDUCTOR (id_mae_empresa, activo);
CREATE INDEX idx_mae_conductor_licencia_venc ON MAE_CONDUCTOR (licencia_vencimiento);

-- ------------------------------------------------------------
--  3.7  MAE_USUARIO
-- ------------------------------------------------------------
CREATE TABLE MAE_USUARIO (
    id              UUID                NOT NULL DEFAULT gen_random_uuid(),
    id_mae_empresa  UUID                NOT NULL,
    nombre_completo VARCHAR(200)        NOT NULL,
    email           VARCHAR(150)        NOT NULL,
    password_hash   VARCHAR(200)        NOT NULL,   -- bcrypt / Argon2id recomendado
    rol             rol_usuario         NOT NULL DEFAULT 'OPERADOR',
    activo          BOOLEAN             NOT NULL DEFAULT TRUE,
    ultimo_acceso   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ         NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_usuario
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_usuario_email
        UNIQUE (id_mae_empresa, email),
    CONSTRAINT fk_mae_usuario_empresa
        FOREIGN KEY (id_mae_empresa) REFERENCES MAE_EMPRESA (id),
    CONSTRAINT ck_mae_usuario_email
        CHECK (email ~ '^[^@\s]+@[^@\s]+\.[^@\s]+$')
);

COMMENT ON TABLE  MAE_USUARIO               IS 'Usuarios del sistema, aislados por empresa (multi-tenant).';
COMMENT ON COLUMN MAE_USUARIO.password_hash IS 'Hash de contraseña. Usar Argon2id o bcrypt — nunca MD5/SHA1.';
COMMENT ON COLUMN MAE_USUARIO.rol           IS 'ADMIN > SUPERVISOR > OPERADOR > CONSULTA.';

CREATE INDEX idx_mae_usuario_empresa ON MAE_USUARIO (id_mae_empresa, activo);

-- ------------------------------------------------------------
--  3.8  MAE_SERIE_DOCUMENTO  (control de correlativos por establecimiento)
-- ------------------------------------------------------------
CREATE TABLE MAE_SERIE_DOCUMENTO (
    id                      UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_mae_establecimiento  UUID            NOT NULL,
    tipo_doc                VARCHAR(3)      NOT NULL,   -- 'T09' guía remitente / 'T31' guía transportista
    serie                   CHAR(4)         NOT NULL,
    correlativo_actual      INTEGER         NOT NULL DEFAULT 0,
    activo                  BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at              TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_mae_serie_documento
        PRIMARY KEY (id),
    CONSTRAINT uq_mae_serie_documento
        UNIQUE (id_mae_establecimiento, tipo_doc, serie),
    CONSTRAINT fk_mae_serie_establecimiento
        FOREIGN KEY (id_mae_establecimiento) REFERENCES MAE_ESTABLECIMIENTO (id),
    CONSTRAINT ck_mae_serie_formato
        CHECK (serie ~ '^[A-Z]\d{3}$'),
    CONSTRAINT ck_mae_serie_tipo_doc
        CHECK (tipo_doc IN ('T09', 'T31')),
    CONSTRAINT ck_mae_correlativo_positivo
        CHECK (correlativo_actual >= 0)
);

COMMENT ON TABLE  MAE_SERIE_DOCUMENTO                  IS 'Control de series y correlativos por tipo de documento y establecimiento.';
COMMENT ON COLUMN MAE_SERIE_DOCUMENTO.tipo_doc         IS 'T09 = Guía Remitente; T31 = Guía Transportista.';
COMMENT ON COLUMN MAE_SERIE_DOCUMENTO.serie            IS 'Formato: letra + 3 dígitos (T001, V002, etc.).';
COMMENT ON COLUMN MAE_SERIE_DOCUMENTO.correlativo_actual IS 'Último correlativo emitido. La función fn_siguiente_correlativo lo incrementa con bloqueo.';
-- ============================================================
--  4.  TABLAS TRANSACCIONALES (TRS_)
-- ============================================================

-- ------------------------------------------------------------
--  4.1  TRS_GUIA_REMISION  (documento principal)
-- ------------------------------------------------------------
CREATE TABLE TRS_GUIA_REMISION (
    id                          UUID                        NOT NULL DEFAULT gen_random_uuid(),
    id_mae_empresa              UUID                        NOT NULL,
    id_mae_establecimiento      UUID                        NOT NULL,
    serie                       CHAR(4)                     NOT NULL,
    correlativo                 VARCHAR(8)                  NOT NULL,
    -- Número completo generado (serie + correlativo), ej: T001-00000001
    numero_completo             VARCHAR(15)                 GENERATED ALWAYS AS (serie || '-' || correlativo) STORED,
    fecha_emision               DATE                        NOT NULL DEFAULT CURRENT_DATE,
    fecha_inicio_traslado       DATE                        NOT NULL,
    motivo_traslado             motivo_traslado             NOT NULL,
    descripcion_motivo          VARCHAR(500),
    modalidad_transporte        modalidad_transporte        NOT NULL,
    -- Partes involucradas
    id_mae_persona_remitente    UUID                        NOT NULL,
    id_mae_persona_destinatario UUID                        NOT NULL,
    -- Ruta de traslado
    direccion_partida           VARCHAR(300)                NOT NULL,
    id_mae_ubigeo_partida       CHAR(6)                     NOT NULL,
    direccion_llegada           VARCHAR(300)                NOT NULL,
    id_mae_ubigeo_llegada       CHAR(6)                     NOT NULL,
    -- Carga
    peso_bruto_total             NUMERIC(12, 3)              NOT NULL,
    unidad_peso                  unidad_peso                 NOT NULL DEFAULT 'KGM',
    num_bultos                   INTEGER,
    -- Datos SUNAT / XML
    hash_cpe                     VARCHAR(500),
    xml_firmado                  TEXT,
    cdr_sunat                    TEXT,
    codigo_respuesta_sunat       VARCHAR(5),
    descripcion_sunat            VARCHAR(500),
    qr_code                      TEXT,
    -- Control
    estado                       estado_guia                 NOT NULL DEFAULT 'BORRADOR',
    observaciones                VARCHAR(1000),
    id_mae_usuario                UUID                        NOT NULL,
    created_at                   TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    updated_at                   TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    enviado_at                    TIMESTAMPTZ,
    anulado_at                    TIMESTAMPTZ,
    motivo_anulacion              VARCHAR(500),
    CONSTRAINT pk_trs_guia_remision
        PRIMARY KEY (id),
    CONSTRAINT uq_trs_guia_numero
        UNIQUE (id_mae_empresa, serie, correlativo),
    CONSTRAINT fk_trs_guia_empresa
        FOREIGN KEY (id_mae_empresa)              REFERENCES MAE_EMPRESA (id),
    CONSTRAINT fk_trs_guia_establecimiento
        FOREIGN KEY (id_mae_establecimiento)      REFERENCES MAE_ESTABLECIMIENTO (id),
    CONSTRAINT fk_trs_guia_remitente
        FOREIGN KEY (id_mae_persona_remitente)    REFERENCES MAE_PERSONA (id),
    CONSTRAINT fk_trs_guia_destinatario
        FOREIGN KEY (id_mae_persona_destinatario) REFERENCES MAE_PERSONA (id),
    CONSTRAINT fk_trs_guia_ubigeo_partida
        FOREIGN KEY (id_mae_ubigeo_partida)       REFERENCES MAE_UBIGEO (id),
    CONSTRAINT fk_trs_guia_ubigeo_llegada
        FOREIGN KEY (id_mae_ubigeo_llegada)       REFERENCES MAE_UBIGEO (id),
    CONSTRAINT fk_trs_guia_usuario
        FOREIGN KEY (id_mae_usuario)              REFERENCES MAE_USUARIO (id),
    CONSTRAINT ck_trs_guia_fechas
        CHECK (fecha_inicio_traslado >= fecha_emision),
    CONSTRAINT ck_trs_guia_peso
        CHECK (peso_bruto_total > 0),
    CONSTRAINT ck_trs_guia_bultos
        CHECK (num_bultos IS NULL OR num_bultos > 0),
    CONSTRAINT ck_trs_guia_serie_formato
        CHECK (serie ~ '^[A-Z]\d{3}$'),
    CONSTRAINT ck_trs_guia_correlativo_fmt
        CHECK (correlativo ~ '^\d{1,8}$'),
    CONSTRAINT ck_trs_guia_anulacion
        CHECK (
            (estado = 'ANULADA' AND anulado_at IS NOT NULL AND motivo_anulacion IS NOT NULL)
            OR estado <> 'ANULADA'
        )
);

COMMENT ON TABLE  TRS_GUIA_REMISION                    IS 'Documento principal: Guía de Remisión Electrónica — Remitente (GRE).';
COMMENT ON COLUMN TRS_GUIA_REMISION.numero_completo    IS 'SERIE-CORRELATIVO generado (ej: T001-00000001). No editable.';
COMMENT ON COLUMN TRS_GUIA_REMISION.hash_cpe           IS 'Resumen SHA-256 del comprobante para validación SUNAT.';
COMMENT ON COLUMN TRS_GUIA_REMISION.xml_firmado        IS 'XML UBL 2.1 firmado digitalmente con certificado de la empresa.';
COMMENT ON COLUMN TRS_GUIA_REMISION.cdr_sunat          IS 'CDR (Constancia de Recepción) devuelta por SUNAT.';
COMMENT ON COLUMN TRS_GUIA_REMISION.codigo_respuesta_sunat IS '0 = aceptado; otro código = observado/rechazado.';

CREATE INDEX idx_trs_guia_empresa_fecha    ON TRS_GUIA_REMISION (id_mae_empresa, fecha_emision DESC);
CREATE INDEX idx_trs_guia_empresa_estado   ON TRS_GUIA_REMISION (id_mae_empresa, estado);
CREATE INDEX idx_trs_guia_numero_completo  ON TRS_GUIA_REMISION (id_mae_empresa, numero_completo);
CREATE INDEX idx_trs_guia_remitente        ON TRS_GUIA_REMISION (id_mae_persona_remitente);
CREATE INDEX idx_trs_guia_destinatario     ON TRS_GUIA_REMISION (id_mae_persona_destinatario);
CREATE INDEX idx_trs_guia_fecha_traslado   ON TRS_GUIA_REMISION (fecha_inicio_traslado);
-- Índice parcial: solo registros que requieren acción (útil para procesamiento SUNAT)
CREATE INDEX idx_trs_guia_pendiente_envio  ON TRS_GUIA_REMISION (id_mae_empresa, created_at)
    WHERE estado IN ('EMITIDA', 'RECHAZADA');

-- ------------------------------------------------------------
--  4.2  TRS_GUIA_DETALLE  (ítems / productos de la guía)
-- ------------------------------------------------------------
CREATE TABLE TRS_GUIA_DETALLE (
    id                  UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_trs_guia_remision UUID           NOT NULL,
    linea               SMALLINT        NOT NULL,
    codigo_producto     VARCHAR(50),
    descripcion         VARCHAR(500)    NOT NULL,
    cantidad            NUMERIC(12, 3)  NOT NULL,
    unidad_medida       VARCHAR(3)      NOT NULL DEFAULT 'NIU',  -- Catálogo SUNAT N° 3
    peso_unitario       NUMERIC(12, 3),
    -- Peso total = cantidad × peso_unitario (calculado, solo si peso_unitario no es NULL)
    peso_total          NUMERIC(12, 3)  GENERATED ALWAYS AS (
                            CASE
                                WHEN peso_unitario IS NOT NULL
                                THEN ROUND(cantidad * peso_unitario, 3)
                                ELSE NULL
                            END
                        ) STORED,
    lote                VARCHAR(50),
    fecha_vencimiento   DATE,
    serie_item          VARCHAR(100),
    created_at          TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_trs_guia_detalle
        PRIMARY KEY (id),
    CONSTRAINT uq_trs_guia_detalle_linea
        UNIQUE (id_trs_guia_remision, linea),
    CONSTRAINT fk_trs_guia_detalle_guia
        FOREIGN KEY (id_trs_guia_remision)  REFERENCES TRS_GUIA_REMISION (id) ON DELETE CASCADE,
    CONSTRAINT ck_trs_guia_detalle_cantidad
        CHECK (cantidad > 0),
    CONSTRAINT ck_trs_guia_detalle_linea
        CHECK (linea >= 1),
    CONSTRAINT ck_trs_guia_detalle_peso_unit
        CHECK (peso_unitario IS NULL OR peso_unitario >= 0),
    CONSTRAINT ck_trs_guia_detalle_unidad_medida
        CHECK (unidad_medida ~ '^[A-Z0-9]{2,3}$')
);

COMMENT ON TABLE  TRS_GUIA_DETALLE               IS 'Detalle de bienes / productos incluidos en la guía de remisión.';
COMMENT ON COLUMN TRS_GUIA_DETALLE.unidad_medida IS 'Código SUNAT catálogo N° 3: NIU (unidad), KGM (kg), LTR (litro), etc.';
COMMENT ON COLUMN TRS_GUIA_DETALLE.peso_total    IS 'Calculado automáticamente: ROUND(cantidad × peso_unitario, 3).';
COMMENT ON COLUMN TRS_GUIA_DETALLE.lote          IS 'Número de lote para trazabilidad (alimentos, farma, etc.).';

CREATE INDEX idx_trs_guia_detalle_guia ON TRS_GUIA_DETALLE (id_trs_guia_remision);

-- ------------------------------------------------------------
--  4.3  TRS_GUIA_TRANSPORTISTA  (datos del transportista asignado)
-- ------------------------------------------------------------
CREATE TABLE TRS_GUIA_TRANSPORTISTA (
    id                          UUID            NOT NULL DEFAULT gen_random_uuid(),
    id_trs_guia_remision        UUID            NOT NULL,
    -- Opción A: transportista registrado en el sistema
    id_mae_vehiculo             UUID,
    id_mae_conductor            UUID,
    -- Opción B: transportista externo (datos manuales)
    ruc_transportista           CHAR(11),
    razon_social_transportista  VARCHAR(200),
    placa_manual                VARCHAR(10),
    licencia_manual             VARCHAR(20),
    tipo_doc_conductor          tipo_documento_identidad,
    num_doc_conductor           VARCHAR(20),
    nombre_conductor            VARCHAR(200),
    created_at                  TIMESTAMPTZ     NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_trs_guia_transportista
        PRIMARY KEY (id),
    CONSTRAINT uq_trs_guia_transportista
        UNIQUE (id_trs_guia_remision),
    CONSTRAINT fk_trs_guia_transp_guia
        FOREIGN KEY (id_trs_guia_remision) REFERENCES TRS_GUIA_REMISION (id) ON DELETE CASCADE,
    CONSTRAINT fk_trs_guia_transp_vehiculo
        FOREIGN KEY (id_mae_vehiculo)      REFERENCES MAE_VEHICULO (id),
    CONSTRAINT fk_trs_guia_transp_conductor
        FOREIGN KEY (id_mae_conductor)     REFERENCES MAE_CONDUCTOR (id),
    -- Se debe registrar al menos una de las dos opciones
    CONSTRAINT ck_trs_guia_transp_datos CHECK (
        (id_mae_vehiculo IS NOT NULL AND id_mae_conductor IS NOT NULL)
        OR
        (ruc_transportista IS NOT NULL
         AND placa_manual    IS NOT NULL
         AND nombre_conductor IS NOT NULL)
    ),
    CONSTRAINT ck_trs_guia_transp_ruc
        CHECK (ruc_transportista IS NULL OR ruc_transportista ~ '^\d{11}$')
);

COMMENT ON TABLE  TRS_GUIA_TRANSPORTISTA IS
    'Transportista asignado a la guía: puede ser interno (id_mae_vehiculo/id_mae_conductor) o externo (datos manuales).';

CREATE INDEX idx_trs_guia_transportista_guia      ON TRS_GUIA_TRANSPORTISTA (id_trs_guia_remision);
CREATE INDEX idx_trs_guia_transportista_conductor ON TRS_GUIA_TRANSPORTISTA (id_mae_conductor);
CREATE INDEX idx_trs_guia_transportista_vehiculo  ON TRS_GUIA_TRANSPORTISTA (id_mae_vehiculo);

-- ------------------------------------------------------------
--  4.4  TRS_GUIA_REFERENCIA  (documentos relacionados)
-- ------------------------------------------------------------
CREATE TABLE TRS_GUIA_REFERENCIA (
    id                      UUID                        NOT NULL DEFAULT gen_random_uuid(),
    id_trs_guia_remision    UUID                        NOT NULL,
    tipo_doc                tipo_doc_referencia         NOT NULL,
    serie                   CHAR(4)                     NOT NULL,
    correlativo             VARCHAR(8)                  NOT NULL,
    fecha_emision           DATE,
    created_at              TIMESTAMPTZ                 NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_trs_guia_referencia
        PRIMARY KEY (id),
    CONSTRAINT uq_trs_guia_referencia
        UNIQUE (id_trs_guia_remision, tipo_doc, serie, correlativo),
    CONSTRAINT fk_trs_guia_ref_guia
        FOREIGN KEY (id_trs_guia_remision) REFERENCES TRS_GUIA_REMISION (id) ON DELETE CASCADE,
    CONSTRAINT ck_trs_guia_ref_serie
        CHECK (serie ~ '^[A-Z0-9]\d{3}$')
);

COMMENT ON TABLE TRS_GUIA_REFERENCIA IS
    'Documentos de referencia vinculados a la guía (facturas, boletas, OC, otras guías).';

CREATE INDEX idx_trs_guia_referencia_guia ON TRS_GUIA_REFERENCIA (id_trs_guia_remision);

-- ============================================================
--  5.  AUDITORÍA (LOG_)  — particionada por año
-- ============================================================
CREATE TABLE LOG_GUIA (
    id              BIGSERIAL               NOT NULL,
    id_trs_guia_remision UUID               NOT NULL,
    id_mae_empresa  UUID                    NOT NULL,
    id_mae_usuario  UUID,
    accion          VARCHAR(50)             NOT NULL,
    estado_anterior estado_guia,
    estado_nuevo    estado_guia,
    detalle         JSONB,
    ip_address      INET,
    user_agent      VARCHAR(500),           -- agente HTTP para trazabilidad
    created_at      TIMESTAMPTZ             NOT NULL DEFAULT NOW(),
    CONSTRAINT pk_log_guia PRIMARY KEY (id, created_at)
) PARTITION BY RANGE (created_at);

COMMENT ON TABLE  LOG_GUIA IS
    'Log de auditoría de todas las operaciones sobre guías de remisión. Particionado por año.';
COMMENT ON COLUMN LOG_GUIA.accion IS
    'Valores esperados: CREAR, EDITAR, CAMBIO_ESTADO, ANULAR, ENVIAR_SUNAT, REENVIAR_SUNAT.';
COMMENT ON COLUMN LOG_GUIA.detalle IS
    'Payload JSONB libre: datos adicionales del evento (antes/después, errores, etc.).';

-- Particiones anuales (ampliar según necesidad)
CREATE TABLE LOG_GUIA_2024 PARTITION OF LOG_GUIA
    FOR VALUES FROM ('2024-01-01') TO ('2025-01-01');
CREATE TABLE LOG_GUIA_2025 PARTITION OF LOG_GUIA
    FOR VALUES FROM ('2025-01-01') TO ('2026-01-01');
CREATE TABLE LOG_GUIA_2026 PARTITION OF LOG_GUIA
    FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
CREATE TABLE LOG_GUIA_2027 PARTITION OF LOG_GUIA
    FOR VALUES FROM ('2027-01-01') TO ('2028-01-01');

CREATE INDEX idx_log_guia_id       ON LOG_GUIA (id_trs_guia_remision);
CREATE INDEX idx_log_guia_empresa  ON LOG_GUIA (id_mae_empresa, created_at DESC);
CREATE INDEX idx_log_guia_usuario  ON LOG_GUIA (id_mae_usuario, created_at DESC);
CREATE INDEX idx_log_guia_accion   ON LOG_GUIA (accion, created_at DESC);
-- ============================================================
--  6.  FUNCIONES DE DOMINIO Y NEGOCIO
--      (sin triggers — la lógica la orquesta la aplicación
--       o los procedimientos almacenados explícitos)
-- ============================================================

-- ------------------------------------------------------------
--  6.1  fn_siguiente_correlativo
--       Obtiene y reserva el próximo correlativo con bloqueo
--       optimista a nivel de fila (SELECT ... FOR UPDATE).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_siguiente_correlativo(
    p_id_mae_establecimiento   UUID,
    p_tipo_doc                 VARCHAR,
    p_serie                    CHAR(4)
)
RETURNS VARCHAR(8)
LANGUAGE plpgsql
AS $$
DECLARE
    v_correlativo INTEGER;
BEGIN
    UPDATE MAE_SERIE_DOCUMENTO
    SET    correlativo_actual = correlativo_actual + 1
    WHERE  id_mae_establecimiento = p_id_mae_establecimiento
      AND  tipo_doc               = p_tipo_doc
      AND  serie                  = p_serie
      AND  activo                 = TRUE
    RETURNING correlativo_actual INTO v_correlativo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Serie % tipo % no encontrada o inactiva para el establecimiento %.',
            p_serie, p_tipo_doc, p_id_mae_establecimiento
            USING ERRCODE = 'P0002';
    END IF;

    RETURN LPAD(v_correlativo::TEXT, 8, '0');
END;
$$;

COMMENT ON FUNCTION fn_siguiente_correlativo(UUID, VARCHAR, CHAR) IS
    'Incrementa y retorna el siguiente correlativo disponible (con bloqueo de fila). '
    'Formato de salida: 8 dígitos con ceros a la izquierda (ej: 00000042).';

-- ------------------------------------------------------------
--  6.2  fn_registrar_auditoria
--       Inserta una entrada en el log de auditoría.
--       Llamar explícitamente desde la capa de servicio o
--       desde los procedimientos sp_*.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_registrar_auditoria(
    p_id_trs_guia_remision  UUID,
    p_id_mae_empresa        UUID,
    p_id_mae_usuario        UUID,
    p_accion                VARCHAR(50),
    p_estado_ant            estado_guia         DEFAULT NULL,
    p_estado_nuevo          estado_guia         DEFAULT NULL,
    p_detalle               JSONB               DEFAULT NULL,
    p_ip                    INET                DEFAULT NULL,
    p_user_agent            VARCHAR(500)        DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO LOG_GUIA
        (id_trs_guia_remision, id_mae_empresa, id_mae_usuario, accion,
         estado_anterior, estado_nuevo, detalle, ip_address, user_agent)
    VALUES
        (p_id_trs_guia_remision, p_id_mae_empresa, p_id_mae_usuario, p_accion,
         p_estado_ant, p_estado_nuevo, p_detalle, p_ip, p_user_agent);

EXCEPTION WHEN OTHERS THEN
    -- El fallo del log no debe bloquear la operación principal;
    -- se registra en el log de errores de PostgreSQL.
    RAISE WARNING 'fn_registrar_auditoria: no se pudo insertar log para id_trs_guia_remision=%. Error: %',
        p_id_trs_guia_remision, SQLERRM;
END;
$$;

COMMENT ON FUNCTION fn_registrar_auditoria IS
    'Registra una entrada de auditoría. Los errores se advierten sin propagar '
    'para no afectar la transacción principal.';

-- ------------------------------------------------------------
--  6.3  fn_marcar_updated_at
--       Actualiza el campo updated_at de cualquier tabla que lo tenga.
--       Se llama explícitamente en los sp_* al hacer UPDATE,
--       eliminando la dependencia de triggers.
-- ------------------------------------------------------------
-- Nota: con PostgreSQL 15+ la forma más limpia es simplemente incluir
-- updated_at = NOW() en cada UPDATE. La función queda como utilidad
-- para casos en que la capa de aplicación lo necesite.

-- ------------------------------------------------------------
--  6.4  fn_validar_transicion_estado
--       Valida que el cambio de estado sea permitido según el
--       diagrama de estados de la guía.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_transicion_estado(
    p_estado_actual estado_guia,
    p_estado_nuevo  estado_guia
)
RETURNS BOOLEAN
LANGUAGE plpgsql IMMUTABLE
AS $$
/*
    Diagrama de transiciones permitidas:
    BORRADOR       → EMITIDA, ANULADA
    EMITIDA        → ENVIADA_SUNAT, ANULADA
    ENVIADA_SUNAT  → ACEPTADA, RECHAZADA
    ACEPTADA       → BAJA
    RECHAZADA      → EMITIDA   (re-emitir corrección)
    ANULADA        → (estado final)
    BAJA           → (estado final)
*/
BEGIN
    RETURN CASE p_estado_actual
        WHEN 'BORRADOR'      THEN p_estado_nuevo IN ('EMITIDA',        'ANULADA')
        WHEN 'EMITIDA'       THEN p_estado_nuevo IN ('ENVIADA_SUNAT',  'ANULADA')
        WHEN 'ENVIADA_SUNAT' THEN p_estado_nuevo IN ('ACEPTADA',       'RECHAZADA')
        WHEN 'ACEPTADA'      THEN p_estado_nuevo IN ('BAJA')
        WHEN 'RECHAZADA'     THEN p_estado_nuevo IN ('EMITIDA')
        WHEN 'ANULADA'       THEN FALSE
        WHEN 'BAJA'          THEN FALSE
        ELSE FALSE
    END;
END;
$$;

COMMENT ON FUNCTION fn_validar_transicion_estado IS
    'Devuelve TRUE si la transición de estado es válida según el flujo oficial de la GRE.';

-- ------------------------------------------------------------
--  6.5  fn_estadisticas_empresa
--       Resumen operativo de guías por empresa y período.
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_estadisticas_empresa(
    p_id_mae_empresa    UUID,
    p_fecha_desde       DATE DEFAULT DATE_TRUNC('month', CURRENT_DATE)::DATE,
    p_fecha_hasta       DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    estado          estado_guia,
    cantidad        BIGINT,
    peso_total_kg   NUMERIC,
    ultimo_emitido  DATE
)
LANGUAGE sql STABLE
AS $$
    SELECT
        g.estado,
        COUNT(*)                                                AS cantidad,
        ROUND(SUM(
            CASE g.unidad_peso
                WHEN 'KGM' THEN g.peso_bruto_total
                WHEN 'TNE' THEN g.peso_bruto_total * 1000
                WHEN 'GRM' THEN g.peso_bruto_total / 1000
                WHEN 'LBR' THEN g.peso_bruto_total * 0.453592
            END
        ), 2)                                                   AS peso_total_kg,
        MAX(g.fecha_emision)                                    AS ultimo_emitido
    FROM  TRS_GUIA_REMISION g
    WHERE g.id_mae_empresa = p_id_mae_empresa
      AND g.fecha_emision  BETWEEN p_fecha_desde AND p_fecha_hasta
    GROUP BY g.estado
    ORDER BY g.estado;
$$;

COMMENT ON FUNCTION fn_estadisticas_empresa IS
    'Resumen de guías agrupado por estado para una empresa y rango de fechas. '
    'Convierte todos los pesos a KGM para comparación.';

-- ============================================================
--  7.  PROCEDIMIENTOS ALMACENADOS (orquestación de negocio)
-- ============================================================

-- ------------------------------------------------------------
--  7.1  sp_crear_guia
--       Crea una guía en estado BORRADOR con sus detalles y
--       el transportista. Asigna correlativo y registra auditoría.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_crear_guia(
    p_id_mae_empresa            UUID,
    p_id_mae_establecimiento    UUID,
    p_serie                     CHAR(4),
    p_fecha_inicio_traslado     DATE,
    p_motivo_traslado           motivo_traslado,
    p_descripcion_motivo        VARCHAR,
    p_modalidad_transporte      modalidad_transporte,
    p_id_mae_persona_remitente     UUID,
    p_id_mae_persona_destinatario  UUID,
    p_direccion_partida         VARCHAR,
    p_id_mae_ubigeo_partida     CHAR(6),
    p_direccion_llegada         VARCHAR,
    p_id_mae_ubigeo_llegada     CHAR(6),
    p_peso_bruto_total          NUMERIC,
    p_unidad_peso                unidad_peso,
    p_num_bultos                 INTEGER,
    p_observaciones               VARCHAR,
    p_id_mae_usuario              UUID,
    p_ip                          INET            DEFAULT NULL,
    -- Parámetros de salida
    INOUT p_id_trs_guia_remision  UUID            DEFAULT NULL,
    INOUT p_numero_completo       VARCHAR(15)     DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_correlativo   VARCHAR(8);
    v_tipo_doc      VARCHAR(3) := 'T09';
BEGIN
    -- 1. Obtener y reservar el siguiente correlativo (con bloqueo)
    v_correlativo := fn_siguiente_correlativo(
        p_id_mae_establecimiento, v_tipo_doc, p_serie
    );

    -- 2. Insertar la guía en estado BORRADOR
    INSERT INTO TRS_GUIA_REMISION (
        id_mae_empresa, id_mae_establecimiento,
        serie, correlativo,
        fecha_emision, fecha_inicio_traslado,
        motivo_traslado, descripcion_motivo,
        modalidad_transporte,
        id_mae_persona_remitente, id_mae_persona_destinatario,
        direccion_partida, id_mae_ubigeo_partida,
        direccion_llegada, id_mae_ubigeo_llegada,
        peso_bruto_total, unidad_peso, num_bultos,
        observaciones, id_mae_usuario,
        estado
    ) VALUES (
        p_id_mae_empresa, p_id_mae_establecimiento,
        p_serie, v_correlativo,
        CURRENT_DATE, p_fecha_inicio_traslado,
        p_motivo_traslado, p_descripcion_motivo,
        p_modalidad_transporte,
        p_id_mae_persona_remitente, p_id_mae_persona_destinatario,
        p_direccion_partida, p_id_mae_ubigeo_partida,
        p_direccion_llegada, p_id_mae_ubigeo_llegada,
        p_peso_bruto_total, p_unidad_peso, p_num_bultos,
        p_observaciones, p_id_mae_usuario,
        'BORRADOR'
    )
    RETURNING id, numero_completo
    INTO p_id_trs_guia_remision, p_numero_completo;

    -- 3. Registrar en auditoría
    PERFORM fn_registrar_auditoria(
        p_id_trs_guia_remision, p_id_mae_empresa, p_id_mae_usuario,
        'CREAR', NULL, 'BORRADOR',
        jsonb_build_object('numero', p_numero_completo),
        p_ip
    );

EXCEPTION WHEN OTHERS THEN
    RAISE;   -- Re-lanzar para que el cliente maneje el rollback
END;
$$;

COMMENT ON PROCEDURE sp_crear_guia IS
    'Crea una nueva guía de remisión en estado BORRADOR. '
    'Reserva correlativo, inserta el cabezal y registra la auditoría en una sola transacción.';

-- ------------------------------------------------------------
--  7.2  sp_cambiar_estado_guia
--       Aplica una transición de estado validada con auditoría.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_cambiar_estado_guia(
    p_id_trs_guia_remision  UUID,
    p_estado_nuevo          estado_guia,
    p_id_mae_usuario        UUID,
    p_motivo_anulacion      VARCHAR(500)    DEFAULT NULL,
    p_detalle               JSONB           DEFAULT NULL,
    p_ip                     INET            DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_mae_empresa    UUID;
    v_estado_actual     estado_guia;
BEGIN
    -- 1. Leer estado actual con bloqueo para evitar condición de carrera
    SELECT id_mae_empresa, estado
    INTO   v_id_mae_empresa, v_estado_actual
    FROM   TRS_GUIA_REMISION
    WHERE  id = p_id_trs_guia_remision
    FOR    UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Guía % no encontrada.', p_id_trs_guia_remision
            USING ERRCODE = 'P0002';
    END IF;

    -- 2. Validar transición
    IF NOT fn_validar_transicion_estado(v_estado_actual, p_estado_nuevo) THEN
        RAISE EXCEPTION
            'Transición de estado no permitida: % → %.', v_estado_actual, p_estado_nuevo
            USING ERRCODE = 'P0001';
    END IF;

    -- 3. Aplicar cambio de estado
    UPDATE TRS_GUIA_REMISION
    SET
        estado           = p_estado_nuevo,
        updated_at       = NOW(),
        anulado_at       = CASE WHEN p_estado_nuevo = 'ANULADA' THEN NOW() ELSE anulado_at END,
        motivo_anulacion = CASE WHEN p_estado_nuevo = 'ANULADA' THEN p_motivo_anulacion ELSE motivo_anulacion END,
        enviado_at       = CASE WHEN p_estado_nuevo = 'ENVIADA_SUNAT' THEN NOW() ELSE enviado_at END
    WHERE id = p_id_trs_guia_remision;

    -- 4. Registrar en auditoría
    PERFORM fn_registrar_auditoria(
        p_id_trs_guia_remision, v_id_mae_empresa, p_id_mae_usuario,
        'CAMBIO_ESTADO',
        v_estado_actual, p_estado_nuevo,
        p_detalle,
        p_ip
    );

EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

COMMENT ON PROCEDURE sp_cambiar_estado_guia IS
    'Cambia el estado de una guía aplicando las reglas de transición. '
    'Usa SELECT FOR UPDATE para evitar condiciones de carrera en entornos concurrentes.';

-- ------------------------------------------------------------
--  7.3  sp_agregar_detalle_guia
--       Añade o reemplaza un ítem en el detalle de la guía.
--       Solo permite modificar guías en estado BORRADOR.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_agregar_detalle_guia(
    p_id_trs_guia_remision  UUID,
    p_linea                 SMALLINT,
    p_codigo_producto       VARCHAR(50)     DEFAULT NULL,
    p_descripcion           VARCHAR(500)    DEFAULT NULL,
    p_cantidad              NUMERIC(12,3)   DEFAULT NULL,
    p_unidad_medida         VARCHAR(3)      DEFAULT 'NIU',
    p_peso_unitario         NUMERIC(12,3)   DEFAULT NULL,
    p_lote                  VARCHAR(50)     DEFAULT NULL,
    p_fecha_vencimiento     DATE            DEFAULT NULL,
    p_serie_item            VARCHAR(100)    DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado estado_guia;
BEGIN
    SELECT estado INTO v_estado
    FROM TRS_GUIA_REMISION
    WHERE id = p_id_trs_guia_remision;

    IF v_estado <> 'BORRADOR' THEN
        RAISE EXCEPTION
            'Solo se pueden agregar ítems a guías en estado BORRADOR. Estado actual: %.',
            v_estado
            USING ERRCODE = 'P0001';
    END IF;

    INSERT INTO TRS_GUIA_DETALLE (
        id_trs_guia_remision, linea, codigo_producto, descripcion,
        cantidad, unidad_medida, peso_unitario,
        lote, fecha_vencimiento, serie_item
    ) VALUES (
        p_id_trs_guia_remision, p_linea, p_codigo_producto, p_descripcion,
        p_cantidad, p_unidad_medida, p_peso_unitario,
        p_lote, p_fecha_vencimiento, p_serie_item
    )
    ON CONFLICT (id_trs_guia_remision, linea)
    DO UPDATE SET
        codigo_producto   = EXCLUDED.codigo_producto,
        descripcion       = EXCLUDED.descripcion,
        cantidad          = EXCLUDED.cantidad,
        unidad_medida     = EXCLUDED.unidad_medida,
        peso_unitario     = EXCLUDED.peso_unitario,
        lote              = EXCLUDED.lote,
        fecha_vencimiento = EXCLUDED.fecha_vencimiento,
        serie_item        = EXCLUDED.serie_item;
END;
$$;

COMMENT ON PROCEDURE sp_agregar_detalle_guia IS
    'Inserta o actualiza (upsert) un ítem del detalle. Solo opera sobre guías en BORRADOR.';

-- ------------------------------------------------------------
--  7.4  sp_registrar_respuesta_sunat
--       Persiste la respuesta CDR de SUNAT y actualiza estado.
-- ------------------------------------------------------------
CREATE OR REPLACE PROCEDURE sp_registrar_respuesta_sunat(
    p_id_trs_guia_remision  UUID,
    p_codigo_respuesta      VARCHAR(5),
    p_descripcion_sunat     VARCHAR(500),
    p_cdr_sunat             TEXT,
    p_id_mae_usuario        UUID,
    p_ip                    INET    DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_mae_empresa    UUID;
    v_estado_actual     estado_guia;
    v_estado_nuevo      estado_guia;
BEGIN
    SELECT id_mae_empresa, estado
    INTO   v_id_mae_empresa, v_estado_actual
    FROM   TRS_GUIA_REMISION
    WHERE  id = p_id_trs_guia_remision
    FOR    UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Guía % no encontrada.', p_id_trs_guia_remision
            USING ERRCODE = 'P0002';
    END IF;

    -- Determinar nuevo estado según código SUNAT
    v_estado_nuevo := CASE
        WHEN p_codigo_respuesta = '0' THEN 'ACEPTADA'
        ELSE 'RECHAZADA'
    END;

    -- Actualizar datos SUNAT y estado en un solo UPDATE
    UPDATE TRS_GUIA_REMISION
    SET
        codigo_respuesta_sunat = p_codigo_respuesta,
        descripcion_sunat      = p_descripcion_sunat,
        cdr_sunat              = p_cdr_sunat,
        estado                 = v_estado_nuevo,
        updated_at             = NOW()
    WHERE id = p_id_trs_guia_remision;

    -- Registrar en auditoría con detalle de la respuesta SUNAT
    PERFORM fn_registrar_auditoria(
        p_id_trs_guia_remision, v_id_mae_empresa, p_id_mae_usuario,
        'RESPUESTA_SUNAT',
        v_estado_actual, v_estado_nuevo,
        jsonb_build_object(
            'codigo_sunat',      p_codigo_respuesta,
            'descripcion_sunat', p_descripcion_sunat
        ),
        p_ip
    );

EXCEPTION WHEN OTHERS THEN
    RAISE;
END;
$$;

COMMENT ON PROCEDURE sp_registrar_respuesta_sunat IS
    'Persiste el CDR de SUNAT y transiciona la guía a ACEPTADA (código 0) o RECHAZADA.';
-- ============================================================
--  8.  VISTAS DE CONSULTA
-- ============================================================

-- ------------------------------------------------------------
--  8.1  v_guias  — listado operativo completo
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_guias AS
SELECT
    g.id,
    g.id_mae_empresa,
    e.razon_social                                                  AS empresa,
    g.id_mae_establecimiento,
    est.denominacion                                                AS establecimiento,
    g.serie,
    g.correlativo,
    g.numero_completo,
    g.fecha_emision,
    g.fecha_inicio_traslado,
    g.motivo_traslado,
    g.modalidad_transporte,
    rem.razon_social                                                AS remitente,
    rem.num_doc                                                     AS remitente_doc,
    dest.razon_social                                               AS destinatario,
    dest.num_doc                                                    AS destinatario_doc,
    ub_p.departamento || ' › ' || ub_p.provincia || ' › ' || ub_p.distrito  AS punto_partida,
    ub_l.departamento || ' › ' || ub_l.provincia || ' › ' || ub_l.distrito  AS punto_llegada,
    g.peso_bruto_total,
    g.unidad_peso,
    g.num_bultos,
    g.estado,
    g.codigo_respuesta_sunat,
    u.nombre_completo                                               AS usuario_creador,
    g.created_at,
    g.updated_at,
    g.enviado_at,
    -- Métricas de detalle (subconsultas correlacionadas)
    (SELECT COUNT(*)          FROM TRS_GUIA_DETALLE d WHERE d.id_trs_guia_remision = g.id)  AS num_items,
    (SELECT SUM(d.cantidad)   FROM TRS_GUIA_DETALLE d WHERE d.id_trs_guia_remision = g.id)  AS cantidad_total,
    (SELECT SUM(d.peso_total) FROM TRS_GUIA_DETALLE d WHERE d.id_trs_guia_remision = g.id)  AS peso_calculado_total
FROM       TRS_GUIA_REMISION   g
JOIN       MAE_EMPRESA         e    ON e.id    = g.id_mae_empresa
JOIN       MAE_ESTABLECIMIENTO est  ON est.id  = g.id_mae_establecimiento
JOIN       MAE_PERSONA         rem  ON rem.id  = g.id_mae_persona_remitente
JOIN       MAE_PERSONA         dest ON dest.id = g.id_mae_persona_destinatario
JOIN       MAE_UBIGEO          ub_p ON ub_p.id = g.id_mae_ubigeo_partida
JOIN       MAE_UBIGEO          ub_l ON ub_l.id = g.id_mae_ubigeo_llegada
LEFT JOIN  MAE_USUARIO         u    ON u.id    = g.id_mae_usuario;

COMMENT ON VIEW v_guias IS
    'Vista operativa de guías con datos desnormalizados para consulta rápida.';

-- ------------------------------------------------------------
--  8.2  v_conductores_por_vencer  — alertas de vencimiento de licencias
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_conductores_por_vencer AS
SELECT
    c.id                                                AS id_mae_conductor,
    p.nombre || ' ' || p.apellido_paterno               AS conductor,
    p.num_doc,
    c.licencia_numero,
    c.licencia_tipo,
    c.licencia_vencimiento,
    (c.licencia_vencimiento - CURRENT_DATE)             AS dias_para_vencer,
    CASE
        WHEN c.licencia_vencimiento < CURRENT_DATE      THEN 'VENCIDA'
        WHEN c.licencia_vencimiento <= CURRENT_DATE + 7 THEN 'CRITICA'
        WHEN c.licencia_vencimiento <= CURRENT_DATE + 30 THEN 'PROXIMA'
        ELSE 'VIGENTE'
    END                                                 AS semaforo,
    e.razon_social                                      AS empresa
FROM  MAE_CONDUCTOR  c
JOIN  MAE_PERSONA    p ON p.id = c.id_mae_persona
JOIN  MAE_EMPRESA    e ON e.id = c.id_mae_empresa
WHERE c.activo = TRUE
  AND c.licencia_vencimiento <= CURRENT_DATE + INTERVAL '60 days'
ORDER BY c.licencia_vencimiento;

COMMENT ON VIEW v_conductores_por_vencer IS
    'Conductores cuya licencia vence en los próximos 60 días o ya está vencida. '
    'Semáforo: VENCIDA | CRITICA (≤7 días) | PROXIMA (≤30 días) | VIGENTE.';

-- ------------------------------------------------------------
--  8.3  v_series_correlativo  — estado actual de series
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW v_series_correlativo AS
SELECT
    sd.id,
    e.razon_social                              AS empresa,
    est.denominacion                            AS establecimiento,
    est.codigo                                  AS codigo_establecimiento,
    sd.tipo_doc,
    sd.serie,
    sd.correlativo_actual,
    sd.serie || '-' || LPAD((sd.correlativo_actual + 1)::TEXT, 8, '0') AS proximo_numero,
    sd.activo,
    sd.created_at
FROM  MAE_SERIE_DOCUMENTO  sd
JOIN  MAE_ESTABLECIMIENTO  est ON est.id  = sd.id_mae_establecimiento
JOIN  MAE_EMPRESA          e   ON e.id    = est.id_mae_empresa
ORDER BY e.razon_social, est.codigo, sd.tipo_doc, sd.serie;

COMMENT ON VIEW v_series_correlativo IS
    'Estado actual de series y próximo número a emitir por establecimiento y tipo de documento.';

-- ============================================================
--  9.  SEGURIDAD  (Row Level Security — multi-tenant)
-- ============================================================

-- Habilitar RLS en tablas sensibles
ALTER TABLE TRS_GUIA_REMISION  ENABLE ROW LEVEL SECURITY;
ALTER TABLE TRS_GUIA_DETALLE   ENABLE ROW LEVEL SECURITY;
ALTER TABLE MAE_EMPRESA        ENABLE ROW LEVEL SECURITY;
ALTER TABLE MAE_PERSONA        ENABLE ROW LEVEL SECURITY;
ALTER TABLE MAE_USUARIO        ENABLE ROW LEVEL SECURITY;

-- Política de aislamiento por empresa.
-- La aplicación debe establecer: SET LOCAL app.empresa_id = '<uuid>';
-- Descomentar y adaptar según el proveedor de autenticación:

-- CREATE POLICY pol_guia_empresa ON TRS_GUIA_REMISION
--     USING (id_mae_empresa = current_setting('app.empresa_id', TRUE)::UUID);

-- CREATE POLICY pol_detalle_empresa ON TRS_GUIA_DETALLE
--     USING (
--         id_trs_guia_remision IN (
--             SELECT id FROM TRS_GUIA_REMISION
--             WHERE id_mae_empresa = current_setting('app.empresa_id', TRUE)::UUID
--         )
--     );

-- CREATE POLICY pol_persona_empresa ON MAE_PERSONA
--     USING (id_mae_empresa = current_setting('app.empresa_id', TRUE)::UUID OR id_mae_empresa IS NULL);

-- CREATE POLICY pol_usuario_empresa ON MAE_USUARIO
--     USING (id_mae_empresa = current_setting('app.empresa_id', TRUE)::UUID);

-- ============================================================
--  10.  GRANTS  (ajustar según arquitectura de roles de BD)
-- ============================================================

-- Roles sugeridos:
--   app_rw  → aplicación (lectura/escritura operativa)
--   app_ro  → reportes / BI (solo lectura)
--   app_dba → administración

-- GRANT USAGE ON SCHEMA public TO app_rw, app_ro;

-- GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO app_rw;
-- GRANT SELECT                  ON ALL TABLES IN SCHEMA public TO app_ro;
-- GRANT INSERT                  ON LOG_GUIA                    TO app_rw;
-- GRANT SELECT                  ON LOG_GUIA                    TO app_ro;

-- GRANT EXECUTE ON ALL FUNCTIONS  IN SCHEMA public TO app_rw;
-- GRANT EXECUTE ON ALL PROCEDURES IN SCHEMA public TO app_rw;
-- GRANT USAGE, SELECT ON SEQUENCE log_guia_id_seq TO app_rw;

-- ============================================================
--  FIN DEL SCRIPT  —  guia_remision_v3.sql
-- ============================================================