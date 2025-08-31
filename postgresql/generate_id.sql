CREATE OR REPLACE FUNCTION generate_id(
    p_prefix TEXT,
    p_seq_name TEXT,
    p_seq_suffix TEXT,
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
		
        -- Drop all sequences starting with p_seq_name
        FOR seq_to_drop IN
            SELECT relname
            FROM pg_class
            WHERE relkind = 'S'
              AND relname LIKE p_seq_name || '%'
        LOOP
			IF seq_to_drop = full_seq_name THEN
				CONTINUE;
			END IF;
			
            EXECUTE format('DROP SEQUENCE IF EXISTS %I CASCADE', seq_to_drop);
        END LOOP;
    END IF;

	-- Create sequence if missing
    IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'S' AND relname = full_seq_name) THEN
        EXECUTE format('CREATE SEQUENCE %I START WITH 1 INCREMENT BY 1 MINVALUE 1 CACHE 10', full_seq_name);
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
