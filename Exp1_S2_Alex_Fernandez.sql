-- VARIABLE BIND PARA FECHA DE PROCESO
-- Se realiza de esta forma debido a que en Oracle SQL Developer / Oracle Cloud, el comando VARIABLE NO es compatible con el tipo DATE
VARIABLE b_fecha_proceso  VARCHAR2(10)
EXEC :b_fecha_proceso := TO_CHAR(SYSDATE, 'DD/MM/YYYY');

-- LIMPIEZA DE TABLA DESTINO
TRUNCATE TABLE usuario_clave;

DECLARE
    -- --------------------------------------------------------
    -- VARIABLES 
    -- --------------------------------------------------------
    v_id_emp           empleado.id_emp%TYPE;
    v_run              empleado.numrun_emp%TYPE;
    v_dv               empleado.dvrun_emp%TYPE;
    v_pnombre          empleado.pnombre_emp%TYPE;
    v_apaterno         empleado.appaterno_emp%TYPE;
    v_sueldo           empleado.sueldo_base%TYPE;
    v_fecha_nac        empleado.fecha_nac%TYPE;
    v_fecha_cont       empleado.fecha_contrato%TYPE;
    v_estado_civil     estado_civil.nombre_estado_civil%TYPE;

    -- --------------------------------------------------------
    -- VARIABLES DE CÁLCULO
    -- --------------------------------------------------------
    v_usuario          VARCHAR2(20);
    v_clave            VARCHAR2(30);
    v_anios_trab       NUMBER;
    v_contador         NUMBER := 0;
    v_total_emp        NUMBER;

BEGIN
    -- --------------------------------------------------------
    -- ITERACIÓN DE EMPLEADOS
    -- --------------------------------------------------------
    SELECT COUNT(*) 
    INTO v_total_emp
    FROM empleado
    WHERE id_emp BETWEEN 100 AND 320;

    DBMS_OUTPUT.PUT_LINE('Total empleados a procesar: ' || v_total_emp);

    FOR r IN (
        SELECT 
            e.id_emp,
            e.numrun_emp,
            e.dvrun_emp,
            e.pnombre_emp,
            e.appaterno_emp,
            e.sueldo_base,
            e.fecha_nac,
            e.fecha_contrato,
            ec.nombre_estado_civil
        FROM empleado e
        JOIN estado_civil ec
          ON ec.id_estado_civil = e.id_estado_civil
        WHERE e.id_emp BETWEEN 100 AND 320
        ORDER BY e.id_emp
    ) LOOP

        -- ----------------------------------------------------
        -- ASIGNACIÓN DE VARIABLES
        -- ----------------------------------------------------
        v_id_emp       := r.id_emp;
        v_run          := r.numrun_emp;
        v_dv           := r.dvrun_emp;
        v_pnombre      := r.pnombre_emp;
        v_apaterno     := r.appaterno_emp;
        v_sueldo       := r.sueldo_base;
        v_fecha_nac    := r.fecha_nac;
        v_fecha_cont   := r.fecha_contrato;
        v_estado_civil := r.nombre_estado_civil;

        DBMS_OUTPUT.PUT_LINE('Procesando empleado ID: ' || v_id_emp || ' | RUN: ' || v_run);

        -- ----------------------------------------------------
        -- CÁLCULO AÑOS TRABAJADOS
        -- ----------------------------------------------------
        v_anios_trab := FLOOR(MONTHS_BETWEEN(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), v_fecha_cont) / 12);

        -- ----------------------------------------------------
        -- GENERACIÓN NOMBRE DE USUARIO
        -- ----------------------------------------------------
        v_usuario :=
              LOWER(SUBSTR(v_estado_civil, 1, 1))
           || UPPER(SUBSTR(v_pnombre, 1, 3))
           || LENGTH(v_pnombre)
           || '*'
           || SUBSTR(v_sueldo, -1)
           || v_dv
           || v_anios_trab;

        IF v_anios_trab < 10 THEN
            v_usuario := v_usuario || 'X';
        END IF;

        -- ----------------------------------------------------
        -- GENERACIÓN CLAVE 
        -- ----------------------------------------------------
        v_clave :=
              SUBSTR(v_run, 3, 1)
           || (EXTRACT(YEAR FROM v_fecha_nac) + 2)
           || LPAD(MOD(v_sueldo - 1, 1000), 3, '0');

        IF v_estado_civil IN ('CASADO', 'ACUERDO UNION CIVIL') THEN
            v_clave := v_clave || LOWER(SUBSTR(v_apaterno, 1, 2));
        ELSIF v_estado_civil IN ('DIVORCIADO', 'SOLTERO') THEN
            v_clave := v_clave || LOWER(SUBSTR(v_apaterno, 1, 1) || SUBSTR(v_apaterno, -1, 1));
        ELSIF v_estado_civil = 'VIUDO' THEN
            v_clave := v_clave || LOWER(SUBSTR(v_apaterno, -3, 2));
        ELSIF v_estado_civil = 'SEPARADO' THEN
            v_clave := v_clave || LOWER(SUBSTR(v_apaterno, -2, 2));
        END IF;

        v_clave := v_clave
                   || v_id_emp
                   || TO_CHAR(TO_DATE(:b_fecha_proceso, 'DD/MM/YYYY'), 'MMYYYY');

        -- ----------------------------------------------------
        -- INSERTA REGISTRO EN TABLA USUARIO_CLAVE
        -- ----------------------------------------------------
        INSERT INTO usuario_clave
        (id_emp, numrun_emp, dvrun_emp, nombre_empleado, nombre_usuario, clave_usuario)
        VALUES
        (v_id_emp,
         v_run,
         v_dv,
         v_pnombre || ' ' || v_apaterno,
         v_usuario,
         v_clave);

        v_contador := v_contador + 1;
    END LOOP;

    -- --------------------------------------------------------
    -- CONTROL DE TRANSACCIÓN
    -- --------------------------------------------------------
    IF v_contador = v_total_emp THEN
        DBMS_OUTPUT.PUT_LINE('Todos los empleados fueron procesados correctamente. Confirmando cambios...');
        COMMIT;
    ELSE
        ROLLBACK;
    END IF;

END;
/
