# postGis_cells
postgis function that generates gis elements.
At file
c:\Program Files\PostgreSQL\9.4\data\pg_hba.conf
introduce this line to allow remote connections:
host    all             all             0.0.0.0/0           md5

To create a database in postgis:
CREATE DATABASE example_gis;
CREATE EXTENSION postgis;
bye
