-- GENERATE NEW ID
reset all;
CREATE OR REPLACE FUNCTION generate_id(
    p_seq_name TEXT,
	p_seq_suffix TEXT,
    p_prefix TEXT,
    p_pad_left INT
)
RETURNS TEXT AS $$
DECLARE
    full_seq_name TEXT;
    nextval BIGINT;
    seq_to_drop TEXT;
BEGIN
    full_seq_name := p_seq_name;
    IF p_seq_suffix IS NOT NULL AND p_seq_suffix <> '' THEN
        full_seq_name := p_seq_name || '-' || p_seq_suffix;
    END IF;

	-- Create sequence if missing
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = full_seq_name) THEN
        EXECUTE format('CREATE SEQUENCE %I START WITH 1 INCREMENT BY 1 MINVALUE 1', full_seq_name);
    END IF;

    -- Get next value from the selected sequence
    EXECUTE format('SELECT nextval(%L)', full_seq_name) INTO nextval;

    -- Format the ID
    IF p_prefix IS NULL OR p_prefix = '' THEN
        RETURN LPAD(nextval::TEXT, p_pad_left, '0');
    ELSE
        RETURN p_prefix || LPAD(nextval::TEXT, p_pad_left, '0');
    END IF;
END;
$$ LANGUAGE plpgsql;

-- CLEANUP SEQUENCE 
reset all;
CREATE OR REPLACE FUNCTION cleanup_old_sequences(
    p_base_prefix TEXT,
    p_keep_suffix TEXT
)
RETURNS VOID AS $$
DECLARE
    seq_name TEXT;
    keep_seq TEXT := p_base_prefix || '-' || p_keep_suffix;
BEGIN
    FOR seq_name IN
        SELECT relname
        FROM pg_class
        WHERE relkind = 'S'
          AND relname LIKE p_base_prefix || '-%'
    LOOP
        -- Skip the one we want to keep
        IF seq_name = keep_seq THEN
            CONTINUE;
        END IF;

        -- Drop the old sequence
        EXECUTE format('DROP SEQUENCE IF EXISTS %I CASCADE', seq_name);
    END LOOP;
END;
$$ LANGUAGE plpgsql;

select generate_id('PID-', 'tbl_id_seq', '2025-05', 11);
select cleanup_old_sequences('tbl_id_seq', '2025-04');
SELECT * FROM pg_class WHERE relkind = 'S' AND relname like 'tbl_id_seq_%';


WITH new_id AS (
    SELECT generate_id('INV', '202501', 'INV202501-', 8) AS id
)
SELECT id FROM new_id;
