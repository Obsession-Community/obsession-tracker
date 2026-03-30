-- PostGIS Setup for Obsession Tracker Spatial Data
-- Initialize spatial extensions and create tables for PAD-US and PLSS data

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS postgis_topology;
CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;
CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;

-- Set up spatial reference systems
-- WGS84 (EPSG:4326) is default, but ensure it's available
INSERT INTO spatial_ref_sys (srid, auth_name, auth_srid, proj4text, srtext)
SELECT 4326, 'EPSG', 4326, 
    '+proj=longlat +datum=WGS84 +no_defs',
    'GEOGCS["WGS 84",DATUM["WGS_1984",SPHEROID["WGS 84",6378137,298.257223563,AUTHORITY["EPSG","7030"]],AUTHORITY["EPSG","6326"]],PRIMEM["Greenwich",0,AUTHORITY["EPSG","8901"]],UNIT["degree",0.0174532925199433,AUTHORITY["EPSG","9122"]],AUTHORITY["EPSG","4326"]]'
WHERE NOT EXISTS (SELECT 1 FROM spatial_ref_sys WHERE srid = 4326);

-- Create schema for spatial data
CREATE SCHEMA IF NOT EXISTS spatial_data;

-- Grant permissions
GRANT USAGE ON SCHEMA spatial_data TO PUBLIC;
GRANT CREATE ON SCHEMA spatial_data TO obsession_admin;

-- Create metadata table for tracking data sources
CREATE TABLE IF NOT EXISTS spatial_data.data_source_metadata (
    id SERIAL PRIMARY KEY,
    source_name VARCHAR(100) NOT NULL UNIQUE,
    source_type VARCHAR(50) NOT NULL, -- 'PAD-US', 'BLM-PLSS', 'NPS-API'
    version VARCHAR(20),
    last_updated TIMESTAMP WITH TIME ZONE,
    record_count INTEGER,
    coverage_bounds GEOMETRY(POLYGON, 4326),
    data_quality_notes TEXT,
    attribution TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create spatial index on coverage bounds
CREATE INDEX IF NOT EXISTS idx_data_source_metadata_bounds 
ON spatial_data.data_source_metadata USING GIST (coverage_bounds);

-- Create land ownership master table
CREATE TABLE IF NOT EXISTS spatial_data.land_ownership (
    id SERIAL PRIMARY KEY,
    external_id VARCHAR(100), -- Source system ID
    ownership_type VARCHAR(50) NOT NULL,
    owner_name VARCHAR(200),
    agency_name VARCHAR(200),
    unit_name VARCHAR(200),
    designation VARCHAR(100),
    access_type VARCHAR(50),
    allowed_uses TEXT[], -- Array of allowed use types
    restrictions TEXT[],
    contact_info TEXT,
    website VARCHAR(500),
    fees TEXT,
    seasonal_info TEXT,
    geometry GEOMETRY(MULTIPOLYGON, 4326) NOT NULL,
    centroid GEOMETRY(POINT, 4326),
    area_acres NUMERIC(12, 2),
    data_source VARCHAR(100) NOT NULL,
    source_metadata JSONB,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create spatial indexes
CREATE INDEX IF NOT EXISTS idx_land_ownership_geometry 
ON spatial_data.land_ownership USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_land_ownership_centroid 
ON spatial_data.land_ownership USING GIST (centroid);

-- Create regular indexes for common queries
CREATE INDEX IF NOT EXISTS idx_land_ownership_type 
ON spatial_data.land_ownership (ownership_type);

CREATE INDEX IF NOT EXISTS idx_land_ownership_source 
ON spatial_data.land_ownership (data_source);

-- Create PLSS grid table
CREATE TABLE IF NOT EXISTS spatial_data.plss_grid (
    id SERIAL PRIMARY KEY,
    plss_id VARCHAR(100) UNIQUE NOT NULL,
    township VARCHAR(10),
    range_ VARCHAR(10),
    section_number INTEGER,
    quarter_section VARCHAR(10),
    legal_description VARCHAR(200),
    geometry GEOMETRY(POLYGON, 4326) NOT NULL,
    centroid GEOMETRY(POINT, 4326),
    area_acres NUMERIC(10, 2),
    survey_type VARCHAR(50),
    special_survey BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create spatial indexes for PLSS
CREATE INDEX IF NOT EXISTS idx_plss_grid_geometry 
ON spatial_data.plss_grid USING GIST (geometry);

CREATE INDEX IF NOT EXISTS idx_plss_grid_centroid 
ON spatial_data.plss_grid USING GIST (centroid);

-- Create composite index for legal land descriptions
CREATE INDEX IF NOT EXISTS idx_plss_township_range_section 
ON spatial_data.plss_grid (township, range_, section_number);

-- Create materialized view for quick land ownership queries
CREATE MATERIALIZED VIEW IF NOT EXISTS spatial_data.land_ownership_summary AS
SELECT 
    ownership_type,
    COUNT(*) as property_count,
    SUM(area_acres) as total_acres,
    ST_Union(geometry) as combined_geometry,
    data_source
FROM spatial_data.land_ownership
GROUP BY ownership_type, data_source;

-- Create index on materialized view
CREATE INDEX IF NOT EXISTS idx_land_ownership_summary_geometry 
ON spatial_data.land_ownership_summary USING GIST (combined_geometry);

-- Create function to refresh materialized views
CREATE OR REPLACE FUNCTION spatial_data.refresh_summary_views()
RETURNS VOID AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY spatial_data.land_ownership_summary;
END;
$$ LANGUAGE plpgsql;

-- Create function to calculate area in acres
CREATE OR REPLACE FUNCTION spatial_data.calculate_area_acres(geom geometry)
RETURNS NUMERIC AS $$
BEGIN
    RETURN ST_Area(ST_Transform(geom, 3857)) * 0.000247105; -- Convert sq meters to acres
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Create trigger to auto-calculate area and centroid
CREATE OR REPLACE FUNCTION spatial_data.update_geometry_properties()
RETURNS TRIGGER AS $$
BEGIN
    NEW.centroid = ST_Centroid(NEW.geometry);
    NEW.area_acres = spatial_data.calculate_area_acres(NEW.geometry);
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply trigger to land ownership table
DROP TRIGGER IF EXISTS trigger_land_ownership_geometry ON spatial_data.land_ownership;
CREATE TRIGGER trigger_land_ownership_geometry
    BEFORE INSERT OR UPDATE ON spatial_data.land_ownership
    FOR EACH ROW
    EXECUTE FUNCTION spatial_data.update_geometry_properties();

-- Apply trigger to PLSS table
DROP TRIGGER IF EXISTS trigger_plss_geometry ON spatial_data.plss_grid;
CREATE TRIGGER trigger_plss_geometry
    BEFORE INSERT OR UPDATE ON spatial_data.plss_grid
    FOR EACH ROW
    EXECUTE FUNCTION spatial_data.update_geometry_properties();

-- Create view for treasure hunting specific queries
CREATE OR REPLACE VIEW spatial_data.treasure_hunting_areas AS
SELECT 
    lo.*,
    CASE 
        WHEN lo.ownership_type ILIKE '%national forest%' THEN 'Metal detecting may be allowed with restrictions'
        WHEN lo.ownership_type ILIKE '%national park%' THEN 'Metal detecting strictly prohibited'
        WHEN lo.ownership_type ILIKE '%blm%' THEN 'Metal detecting generally allowed'
        WHEN lo.ownership_type ILIKE '%state%' THEN 'Check state-specific regulations'
        WHEN lo.ownership_type ILIKE '%private%' THEN 'Private property - permission required'
        ELSE 'Unknown - research required'
    END as metal_detecting_status,
    pg.legal_description as plss_legal_description
FROM spatial_data.land_ownership lo
LEFT JOIN spatial_data.plss_grid pg ON ST_Contains(pg.geometry, lo.centroid)
WHERE lo.ownership_type NOT IN ('unknown', 'water');

-- Insert initial metadata
INSERT INTO spatial_data.data_source_metadata (
    source_name, source_type, version, attribution, data_quality_notes
) VALUES 
(
    'PAD-US',
    'PAD-US',
    '4.1',
    'U.S. Geological Survey (USGS) Gap Analysis Project (GAP), 2024, Protected Areas Database of the United States (PAD-US) 4.1',
    'Official federal protected areas database. Updated quarterly. High accuracy for federal lands.'
),
(
    'BLM-PLSS',
    'BLM-PLSS',
    'Current',
    'Bureau of Land Management (BLM) Public Land Survey System (PLSS)',
    'Real-time PLSS grid data. Updated as needed by BLM. For mapping purposes only - not legally authoritative.'
),
(
    'NPS-API',
    'NPS-API',
    'v1',
    'National Park Service API',
    'Real-time park information. Updated as needed. Point locations only - polygon boundaries from PAD-US.'
)
ON CONFLICT (source_name) DO NOTHING;

-- Create optimization settings for spatial queries
-- Increase work_mem for spatial operations
ALTER SYSTEM SET work_mem = '256MB';
ALTER SYSTEM SET maintenance_work_mem = '512MB';
ALTER SYSTEM SET shared_preload_libraries = 'postgis';

-- Reload configuration (requires restart in production)
-- SELECT pg_reload_conf();

-- Success message
DO $$
BEGIN
    RAISE NOTICE 'PostGIS spatial database initialized successfully!';
    RAISE NOTICE 'Created schema: spatial_data';
    RAISE NOTICE 'Created tables: land_ownership, plss_grid, data_source_metadata';
    RAISE NOTICE 'Created indexes for spatial queries';
    RAISE NOTICE 'Created triggers for automatic geometry calculations';
    RAISE NOTICE 'Ready for PAD-US geodatabase import';
END $$;