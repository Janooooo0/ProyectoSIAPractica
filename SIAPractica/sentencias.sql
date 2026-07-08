BEGIN;

-- =========================
-- UBIGEO
-- =========================
INSERT INTO mae_ubigeo (id, departamento, provincia, distrito) VALUES
('150101','Lima','Lima','Lima'),
('150102','Lima','Lima','Ancon'),
('050101','Arequipa','Arequipa','Arequipa'),
('080101','Cusco','Cusco','Cusco'),
('130101','La Libertad','Trujillo','Trujillo');

-- =========================
-- EMPRESA
-- =========================
INSERT INTO mae_empresa (id, ruc, razon_social, direccion_fiscal, id_mae_ubigeo)
VALUES
(gen_random_uuid(),'20111111111','Empresa A SAC','Lima','150101'),
(gen_random_uuid(),'20222222222','Empresa B SAC','Arequipa','040101'),
(gen_random_uuid(),'20333333333','Empresa C SAC','Cusco','080101'),
(gen_random_uuid(),'20444444444','Empresa D SAC','Piura','150102'),
(gen_random_uuid(),'20555555555','Empresa E SAC','Trujillo','130101');

select * from mae_empresa;

-- =========================
-- USUARIO
-- =========================
INSERT INTO mae_usuario (id, id_mae_empresa, nombre_completo, email, password_hash)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','Usuario A','a@mail.com','hash'),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','Usuario B','b@mail.com','hash'),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','Usuario C','c@mail.com','hash'),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','Usuario D','d@mail.com','hash'),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','Usuario E','e@mail.com','hash');

-- =========================
-- PERSONA
-- =========================
INSERT INTO mae_persona (id, id_mae_empresa, tipo_doc, num_doc, razon_social)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','6','20111111111','Cliente A'),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','6','20222222222','Cliente B'),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','6','20333333333','Cliente C'),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','6','20444444444','Cliente D'),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','6','20555555555','Cliente E');

-- =========================
-- ESTABLECIMIENTO
-- =========================
INSERT INTO mae_establecimiento (id, id_mae_empresa, codigo, denominacion, direccion, id_mae_ubigeo)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','0001','Principal','Dir1','150101'),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','0002','Principal','Dir2','040101'),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','0003','Principal','Dir3','080101'),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','0004','Principal','Dir4','150101'),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','0005','Principal','Dir5','130101');

-- =========================
-- PRODUCTO
-- =========================
INSERT INTO mae_producto (id, id_mae_empresa, codigo, descripcion, stock_actual)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','P001','Smart TV',100),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','P002','Producto 2',200),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','P003','Producto 3',300),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','P004','Producto 4',400),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','P005','Producto 5',500);

-- =========================
-- VEHICULO
-- =========================
INSERT INTO mae_vehiculo (id, id_mae_empresa, marca, placa)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','Toyota','ABC123'),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','Nissan','DEF456'),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','Kia','GHI789'),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','Hyundai','JKL111'),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','Mazda','MNO222');

-- =========================
-- CONDUCTOR
-- =========================
INSERT INTO mae_conductor (id, id_mae_persona, id_mae_empresa, licencia_tipo, licencia_numero, licencia_vencimiento)
VALUES
(gen_random_uuid(),'5e9c8abe-ffc4-4047-a301-c8f22ebb40b7','21e92e36-d96b-48e5-9724-20e0374ed4df','A1','LIC1','2030-01-01'),
(gen_random_uuid(),'ad066e1f-d094-474c-b07b-13f68903c08a','21e92e36-d96b-48e5-9724-20e0374ed4df','A1','LIC2','2030-01-01'),
(gen_random_uuid(),'caf5a5d4-4342-4d79-9b06-f14fa3423650','c4192bd0-f09f-416a-8885-49dcfc823b92','A1','LIC3','2030-01-01'),
(gen_random_uuid(),'ec956ff7-8671-4377-8260-38a03a6cda15','4764060b-30ed-41ac-93b1-bfc8ef3e7a72','A1','LIC4','2030-01-01'),
(gen_random_uuid(),'fbb75635-70ec-49e3-b288-516d6c0de6bc','f5770349-6392-4451-a770-e4fbbedb732c','A1','LIC5','2030-01-01');

select id from mae_empresa;

-- =========================
-- GUIA REMISION
-- =========================
INSERT INTO trs_guia_remision (
id, id_mae_empresa, id_mae_establecimiento, serie, correlativo,
fecha_inicio_traslado, motivo_traslado, modalidad_transporte,
id_mae_persona_remitente, id_mae_persona_destinatario,
direccion_partida, id_mae_ubigeo_partida,
direccion_llegada, id_mae_ubigeo_llegada,
peso_bruto_total, id_mae_usuario)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','cc427e19-6fde-49a3-8a1f-f211c0432c95','T001','00000001',CURRENT_DATE,'01','01','5e9c8abe-ffc4-4047-a301-c8f22ebb40b7','fbb75635-70ec-49e3-b288-516d6c0de6bc','Dir A','150101','Dir B','150102',100,'aeae1974-18fb-44dd-85c9-c4aece36dcc4'),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','0da61f86-0abc-42ed-86d5-aed286a3768e','T001','00000002',CURRENT_DATE,'01','01','ad066e1f-d094-474c-b07b-13f68903c08a','ec956ff7-8671-4377-8260-38a03a6cda15','Dir A','040101','Dir B','150102',200,'9812fba4-7a6b-41fe-8315-cac5f8c92681'),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','55c16966-b267-4571-91ac-c3eb04976acd','T001','00000003',CURRENT_DATE,'01','01','caf5a5d4-4342-4d79-9b06-f14fa3423650','caf5a5d4-4342-4d79-9b06-f14fa3423650','Dir A','080101','Dir B','150102',300,'9804aa94-dfef-4519-ba82-dc0ba4b9801d'),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','de8e66db-8cde-4419-9cc7-8bff47a4968b','T001','00000004',CURRENT_DATE,'01','01','ec956ff7-8671-4377-8260-38a03a6cda15','ad066e1f-d094-474c-b07b-13f68903c08a','Dir A','150101','Dir B','150102',400,'362dcc8e-9c86-4851-8904-2c362676c3d8'),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','e76e0a3d-19af-49e0-a3fb-8effcbefd3d1','T001','00000005',CURRENT_DATE,'01','01','fbb75635-70ec-49e3-b288-516d6c0de6bc','5e9c8abe-ffc4-4047-a301-c8f22ebb40b7','Dir A','130101','Dir B','150102',500,'088b3c7b-df82-4378-a6a7-30ccf167c7b6');

select * from mae_usuario;

SELECT unnest(enum_range(NULL::modalidad_transporte));

-- =========================
-- DETALLE
-- =========================
INSERT INTO trs_guia_detalle (id, id_trs_guia_remision, linea, descripcion, cantidad)
VALUES
(gen_random_uuid(),'b2ddba36-da2d-4e05-8669-c95c06f5749b',1,'Producto 1',10),
(gen_random_uuid(),'030a2330-112a-402d-aced-db8b6000b969',1,'Producto 2',20),
(gen_random_uuid(),'323239e5-cb83-4f81-9ab5-251c2469c09a',1,'Producto 3',30),
(gen_random_uuid(),'d2f125a4-af13-44b7-a4a1-887b9412fd9a',1,'Producto 4',40),
(gen_random_uuid(),'0b12dfc2-934e-4d82-891f-47b27d39df0a',1,'Producto 5',50);

select id from trs_guia_remision;

-- =========================
-- REFERENCIA
-- =========================
INSERT INTO trs_guia_referencia (id, id_trs_guia_remision, tipo_doc, serie, correlativo)
VALUES
(gen_random_uuid(),'b2ddba36-da2d-4e05-8669-c95c06f5749b','01','F001','0001'),
(gen_random_uuid(),'030a2330-112a-402d-aced-db8b6000b969','01','F001','0002'),
(gen_random_uuid(),'323239e5-cb83-4f81-9ab5-251c2469c09a','01','F001','0003'),
(gen_random_uuid(),'d2f125a4-af13-44b7-a4a1-887b9412fd9a','01','F001','0004'),
(gen_random_uuid(),'0b12dfc2-934e-4d82-891f-47b27d39df0a','01','F001','0005');

-- =========================
-- TRANSPORTISTA
-- =========================
INSERT INTO trs_guia_transportista (id, id_trs_guia_remision, id_mae_vehiculo, id_mae_conductor)
VALUES
(gen_random_uuid(),'b2ddba36-da2d-4e05-8669-c95c06f5749b','c41c692d-9b51-4903-9f0f-403666f645b3','7daee78e-9700-4e31-885f-f6c1802c7877'),
(gen_random_uuid(),'030a2330-112a-402d-aced-db8b6000b969','879ba7c8-dd37-4445-9d7b-8f777f967c25','23b83a92-7d52-4ff4-bfb7-540558cbb705'),
(gen_random_uuid(),'323239e5-cb83-4f81-9ab5-251c2469c09a','d443ce1b-8bc5-4fdc-9327-ee5b8671d3e9','4b78c934-c1ca-4653-a01d-b910f391f98d'),
(gen_random_uuid(),'d2f125a4-af13-44b7-a4a1-887b9412fd9a','e1333f0c-39dc-4b19-a5e4-519855ebf49e','e4751068-8fcb-49a1-947b-35849ff5de5b'),
(gen_random_uuid(),'0b12dfc2-934e-4d82-891f-47b27d39df0a','4ddbf0d1-4a76-4996-96eb-71e6af0446d8','22b05a09-daf1-4c41-8c14-30e42e8b0a13');

select id from mae_conductor;

-- =========================
-- LOG
-- =========================
INSERT INTO log_guia (id_trs_guia_remision, id_mae_empresa, accion)
VALUES
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','CREAR'),
(gen_random_uuid(),'21e92e36-d96b-48e5-9724-20e0374ed4df','CREAR'),
(gen_random_uuid(),'c4192bd0-f09f-416a-8885-49dcfc823b92','CREAR'),
(gen_random_uuid(),'4764060b-30ed-41ac-93b1-bfc8ef3e7a72','CREAR'),
(gen_random_uuid(),'f5770349-6392-4451-a770-e4fbbedb732c','CREAR');

select id from mae_empresa;

-- =========================
-- INCREMENTAR CORRELATIVOS T09
-- =========================
-- Reserva el siguiente correlativo para las series T002, T003 y T004.
-- Si estaban en 0, retorna 00000001 y deja correlativo_actual = 1.
SELECT
    v.serie,
    fn_siguiente_correlativo(
        v.id_mae_establecimiento::uuid,
        'T09',
        v.serie::char(4)
    ) AS correlativo_generado
FROM (
    VALUES
        ('42278be9-bd94-4c9d-9386-729476431360', 'T002'),
        ('b7d9b140-4b89-4b11-9ad0-d0ce7d22783c', 'T003'),
        ('7badf06c-3732-469d-ae3a-2c760af3d233', 'T004')
) AS v(id_mae_establecimiento, serie);

-- Opcional: sincroniza correlativo_actual con el mayor correlativo ya emitido
-- en trs_guia_remision para estas series.
UPDATE mae_serie_documento s
SET correlativo_actual = GREATEST(
    s.correlativo_actual,
    COALESCE((
        SELECT MAX(g.correlativo::integer)
        FROM trs_guia_remision g
        WHERE g.id_mae_establecimiento = s.id_mae_establecimiento
          AND g.serie = s.serie
          AND g.correlativo ~ '^[0-9]+$'
    ), 0)
)
WHERE s.tipo_doc = 'T09'
  AND (s.id_mae_establecimiento, s.serie) IN (
      ('42278be9-bd94-4c9d-9386-729476431360'::uuid, 'T002'),
      ('b7d9b140-4b89-4b11-9ad0-d0ce7d22783c'::uuid, 'T003'),
      ('7badf06c-3732-469d-ae3a-2c760af3d233'::uuid, 'T004')
  )
RETURNING id_mae_establecimiento, serie, correlativo_actual;

COMMIT;

ROLLBACK;
