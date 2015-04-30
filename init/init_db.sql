WARNINGS;

DROP DATABASE IF EXISTS msmskit;

CREATE DATABASE msmskit;

GRANT SELECT,INSERT,UPDATE,EXECUTE
	ON msmskit.*
	TO 'dacb'@'128.208.236.38' 
;

USE msmskit;

CREATE TABLE owners (
	owner		VARCHAR(16) NOT NULL PRIMARY KEY,
	email		VARCHAR(32) NOT NULL
);

INSERT INTO owners (owner, email) VALUES ('dacb', 'dacb@uw.edu');
INSERT INTO owners (owner, email) VALUES ('Erik', 'elh@uw.edu');
INSERT INTO owners (owner, email) VALUES ('Tony', 'tswang@uw.edu');

CREATE TABLE RAW_status (
	status_id	SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
	status_text	VARCHAR(128)
);

INSERT INTO RAW_status (status_id, status_text) VALUES (1, "Cataloged");
INSERT INTO RAW_status (status_id, status_text) VALUES (2, "Calculated md5sum");
INSERT INTO RAW_status (status_id, status_text) VALUES (3, "Converted");
INSERT INTO RAW_status (status_id, status_text) VALUES (4, "Queued for analysis");
INSERT INTO RAW_status (status_id, status_text) VALUES (5, "Analysis running");
INSERT INTO RAW_status (status_id, status_text) VALUES (6, "Analysis complete");
INSERT INTO RAW_status (status_id, status_text) VALUES (7, "Conversion failed!");
INSERT INTO RAW_status (status_id, status_text) VALUES (8, "Analysis failed!");

CREATE TABLE RAW_catalog (
	path		VARCHAR(1000) PRIMARY KEY NOT NULL,
	status_id	SMALLINT UNSIGNED NOT NULL DEFAULT 1,
	created		DATETIME,
	cataloged	DATETIME,
	md5summed	DATETIME,
	converted	DATETIME,
	analyzed	DATETIME,
	completed	DATETIME,
	md5		CHAR(32),
	msconvert_log	LONGTEXT,
	sequest_params	LONGTEXT,
	sequest_params_timestamp DATETIME,
	sequest_params_md5 CHAR(32),
	job		LONGTEXT,
	job_log		LONGTEXT,
	RAW_archived	BIT DEFAULT 0,
	mzXML_archived	BIT DEFAULT 0,
	job_archived	BIT DEFAULT 0,
	FOREIGN KEY (status_id) REFERENCES RAW_status(status_id)
);

CREATE VIEW RAW_catalog_dashboard_view AS
	SELECT *, SUBSTRING_INDEX(path, '/', -1) AS basename,  REPLACE(path, SUBSTRING_INDEX(path, '/', -1), '') AS dirname
		FROM RAW_catalog
;

CREATE TABLE experiment_status (
	status_id	SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
	status_text	VARCHAR(128)
);

INSERT INTO experiment_status (status_id, status_text) VALUES (1, "Cataloged");
INSERT INTO experiment_status (status_id, status_text) VALUES (2, "Analysis running");
INSERT INTO experiment_status (status_id, status_text) VALUES (3, "Complete");

CREATE TABLE experiment_catalog (
	path		VARCHAR(1000) PRIMARY KEY NOT NULL,
	status_id	SMALLINT UNSIGNED NOT NULL DEFAULT 1,
	created		DATETIME,
	cataloged	DATETIME,
	analysis	DATETIME,
	analysis_log	LONGTEXT,
	FOREIGN KEY (status_id) REFERENCES run_status(status_id)
);

CREATE TABLE condition_status (
	status_id	SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
	status_text	VARCHAR(128)
);

INSERT INTO condition_status (status_id, status_text) VALUES (1, "Cataloged");
INSERT INTO condition_status (status_id, status_text) VALUES (2, "Analysis running");
INSERT INTO condition_status (status_id, status_text) VALUES (3, "Complete");

CREATE TABLE experiment_condition_catalog (
	path		VARCHAR(1000) PRIMARY KEY NOT NULL,
	description	LONGTEXT,
	experiment_path	VARCHAR(1000) NOT NULL,
	status_id	SMALLINT UNSIGNED NOT NULL DEFAULT 1,
	created		DATETIME,
	cataloged	DATETIME,
	analysis	DATETIME,
	analysis_job	LONGTEXT,
	analysis_log	LONGTEXT,
	complete	DATETIME,
	FOREIGN KEY (status_id) REFERENCES condition_status(status_id),
	FOREIGN KEY (experiment_path) REFERENCES experiment_catalog(path)
);

CREATE TABLE experiment_condition_locus_restrictions (
	condition_path	VARCHAR(1000) NOT NULL,
	locus_prefix	VARCHAR(16) NOT NULL,
	FOREIGN KEY (condition_path) REFERENCES experiment_condition_catalog(path)
);

CREATE TABLE replicate_status (
	status_id	SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
	status_text	VARCHAR(128)
);

INSERT INTO replicate_status (status_id, status_text) VALUES (1, "Cataloged");
INSERT INTO replicate_status (status_id, status_text) VALUES (2, "PeptideProphet running");
INSERT INTO replicate_status (status_id, status_text) VALUES (3, "ProteinProphet running");
INSERT INTO replicate_status (status_id, status_text) VALUES (4, "Complete");

CREATE TABLE condition_replicate_catalog (
	path		VARCHAR(1000) PRIMARY KEY NOT NULL,
	description	LONGTEXT,
	condition_path	VARCHAR(1000) NOT NULL,
	status_id	SMALLINT UNSIGNED NOT NULL DEFAULT 1,
	created		DATETIME,
	cataloged	DATETIME,
	peptide_prophet	DATETIME,
	peptide_prophet_job LONGTEXT,
	peptide_prophet_log LONGTEXT,
	protein_prophet	DATETIME,
	protein_prophet_job LONGTEXT,
	protein_prophet_log LONGTEXT,
	complete	DATETIME,
	FOREIGN KEY (status_id) REFERENCES replicate_status(status_id),
	FOREIGN KEY (condition_path) REFERENCES experiment_condition_catalog(path)
);

CREATE TABLE run_status (
	status_id	SMALLINT UNSIGNED NOT NULL PRIMARY KEY,
	status_text	VARCHAR(128)
);

INSERT INTO run_status (status_id, status_text) VALUES (1, "Cataloged");
INSERT INTO run_status (status_id, status_text) VALUES (2, "Analysis running");
INSERT INTO run_status (status_id, status_text) VALUES (3, "Complete");

CREATE TABLE replicate_run_catalog (
	path		VARCHAR(1000) PRIMARY KEY NOT NULL,
	replicate_path	VARCHAR(1000) NOT NULL,
	description	LONGTEXT,
	status_id	SMALLINT UNSIGNED NOT NULL DEFAULT 1,
	created		DATETIME,
	cataloged	DATETIME,
	analysis	DATETIME,
	analysis_job	DATETIME,
	analysis_log	DATETIME,
	FOREIGN KEY (status_id) REFERENCES run_status(status_id),
	FOREIGN KEY (replicate_path) REFERENCES condition_replicate_catalog(path)
);

DELIMITER $$

CREATE PROCEDURE RAW_in_catalog(IN path_to_RAW VARCHAR(1000), OUT in_catalog SMALLINT UNSIGNED)
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Check if a RAW file exists in the catalog'
BEGIN
	SELECT COUNT(*) INTO in_catalog FROM RAW_catalog WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_add(IN path_to_RAW VARCHAR(1000), IN created_date DATETIME)
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Add a RAW file to the catalog with status Cataloged'
BEGIN
	INSERT INTO RAW_catalog (path, status_id, created, cataloged) VALUES (path_to_RAW, 1, created_date, NOW());
END$$

CREATE PROCEDURE RAW_catalog_md5sum(IN path_to_RAW VARCHAR(1000), IN md5sum CHAR(32), IN md5sum_date DATETIME)
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Insert the md5sum for a RAW file into the catalog, change status'
BEGIN
	UPDATE RAW_catalog SET status_id = 2, md5 = md5sum, md5summed = md5sum_date WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_msconvert(IN path_to_RAW VARCHAR(1000), IN converted_datetime DATETIME, IN msconvert_log_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Load msconvert log for RAW file into the catalog, change status'
BEGIN
	UPDATE RAW_catalog SET status_id = 3, converted=converted_datetime, msconvert_log=LOAD_FILE(msconvert_log_path) WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_set_conversion_failed(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set status for RAW file that conversion failed'
BEGIN
	UPDATE RAW_catalog SET status_id = 7 WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_set_analysis_failed(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set status for RAW file that analysis failed'
BEGIN
	UPDATE RAW_catalog SET status_id = 8 WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_set_analysis_queued(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set status for RAW file that analysis is queued'
BEGIN
	UPDATE RAW_catalog SET status_id = 4 WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_set_analysis_running(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set status for RAW file that analysis is running'
BEGIN
	UPDATE RAW_catalog SET status_id = 5 WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_sequest_params(IN path_to_RAW VARCHAR(1000), IN sequest_params_path VARCHAR(1000), IN sequest_params_datetime DATETIME, IN sequest_params_md5sum CHAR(32))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Load sequest.params for RAW file into the catalog'
BEGIN
        UPDATE RAW_catalog SET sequest_params=LOAD_FILE(sequest_params_path), sequest_params_timestamp=sequest_params_datetime, sequest_params_md5=sequest_params_md5sum WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_job(IN path_to_RAW VARCHAR(1000), IN job_path VARCHAR(1000), IN job_log_datetime DATETIME, IN job_log_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Load job & job log for RAW file into the catalog, change status'
BEGIN
        UPDATE RAW_catalog SET status_id = 6, job=LOAD_FILE(job_path), analyzed=job_log_datetime, job_log=LOAD_FILE(job_log_path) WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_unconverted()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files waiting to be converted'
BEGIN
	SELECT path, IF(status_id = 2, "waiting", "failed") FROM RAW_catalog WHERE status_id = 2 OR status_id = 7 ORDER BY status_id;
END$$

CREATE PROCEDURE RAW_catalog_unanalyzed()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files waiting to be analyzed'
BEGIN
	SELECT path FROM RAW_catalog WHERE status_id = 3;
END$$

CREATE PROCEDURE RAW_catalog_analysis_queued()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files in analysis queue'
BEGIN
	SELECT path FROM RAW_catalog WHERE status_id = 4;
END$$

CREATE PROCEDURE RAW_catalog_analysis_running()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files with analysis running'
BEGIN
	SELECT path FROM RAW_catalog WHERE status_id = 5;
END$$

CREATE PROCEDURE RAW_catalog_conversion_failed()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files with failed conversion'
BEGIN
	SELECT path FROM RAW_catalog WHERE status_id = 7;
END$$

CREATE PROCEDURE RAW_catalog_analysis_failed()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files with failed analysis'
BEGIN
	SELECT path FROM RAW_catalog WHERE status_id = 7;
END$$

CREATE PROCEDURE RAW_catalog_conversion_log(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files with failed analysis'
BEGIN
        SELECT msconvert_log FROM RAW_catalog WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE experiment_in_catalog(IN path_to_experiment VARCHAR(1000), OUT in_catalog SMALLINT UNSIGNED)
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Check if a experiment exists in the catalog'
BEGIN
	SELECT COUNT(*) INTO in_catalog FROM experiment_catalog WHERE path = path_to_experiment;
END$$

CREATE PROCEDURE experiment_catalog_add(IN path_to_experiment VARCHAR(1000), IN created_date DATETIME)
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Add a experiment to the catalog with status Cataloged'
BEGIN
	INSERT INTO experiment_catalog (path, status_id, created, cataloged) VALUES (path_to_experiment, 1, created_date, NOW());
END$$

CREATE PROCEDURE experiment_condition_in_catalog(IN path_to_experiment VARCHAR(1000), IN path_to_condition VARCHAR(1000), OUT in_catalog SMALLINT UNSIGNED)
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Check if an experiment condition exists in the catalog'
BEGIN
	SELECT COUNT(*) INTO in_catalog FROM experiment_condition_catalog WHERE experiment_path = path_to_experiment AND path = path_to_condition;
END$$

CREATE PROCEDURE experiment_condition_catalog_add(IN path_to_experiment VARCHAR(1000), IN path_to_condition VARCHAR(1000), IN description LONGTEXT, IN created_date DATETIME)
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Add an experiment condition to the catalog with status Cataloged'
BEGIN
	INSERT INTO experiment_condition_catalog (path, experiment_path, description, status_id, created, cataloged) VALUES (path_to_condition, path_to_experiment, description, 1, created_date, NOW());
END$$

CREATE PROCEDURE experiment_condition_locus_restriction_add(IN path_to_condition VARCHAR(1000), IN locus_restriction_prefix VARCHAR(16))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Add a locus prefix restriction to a condition'
BEGIN
	INSERT INTO experiment_condition_locus_restrictions (condition_path, locus_prefix) VALUES (path_to_condition, locus_restriction_prefix);
END$$

CREATE PROCEDURE experiment_condition_locus_restrictions(IN path_to_condition VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Get the list of locus restrictions for an exprimental condition'
BEGIN
	SELECT locus_prefix FROM experiment_condition_locus_restrictions WHERE condition_path = path_to_condition;
END$$

CREATE PROCEDURE experiment_conditions_locus_restrictions(IN path_to_condition_i VARCHAR(1000), IN path_to_condition_j VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Get list of shared locus restrictions for two exp. conditions'
BEGIN
	SELECT a.locus_prefix FROM experiment_condition_locus_restrictions AS a INNER JOIN experiment_condition_locus_restrictions AS b ON a.locus_prefix = b.locus_prefix WHERE a.condition_path = path_to_condition_i AND b.condition_path = path_to_condition_j;
END$$

CREATE PROCEDURE condition_replicate_in_catalog(IN path_to_condition VARCHAR(1000), IN path_to_replicate VARCHAR(1000), OUT in_catalog SMALLINT UNSIGNED)
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Check if an experiment condition replicate exists in the catalog'
BEGIN
	SELECT COUNT(*) INTO in_catalog FROM condition_replicate_catalog WHERE condition_path = path_to_condition AND path = path_to_replicate;
END$$

CREATE PROCEDURE condition_replicate_catalog_add(IN path_to_condition VARCHAR(1000), IN path_to_replicate VARCHAR(1000), IN description LONGTEXT, IN created_date DATETIME)
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Add an experiment condition replicate to the catalog'
BEGIN
	INSERT INTO condition_replicate_catalog (path, condition_path, description, status_id, created, cataloged) VALUES (path_to_replicate, path_to_condition, description, 1, created_date, NOW());
END$$

CREATE PROCEDURE replicate_run_in_catalog(IN path_to_replicate VARCHAR(1000), IN path_to_run VARCHAR(1000), OUT in_catalog SMALLINT UNSIGNED)
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Check if an condition replicate run exists in the catalog'
BEGIN
	SELECT COUNT(*) INTO in_catalog FROM replicate_run_catalog WHERE replicate_path = path_to_replicate AND path = path_to_run;
END$$

CREATE PROCEDURE replicate_run_catalog_add(IN path_to_replicate VARCHAR(1000), IN path_to_run VARCHAR(1000), IN description LONGTEXT, IN created_date DATETIME)
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Add an condition replicate run to the catalog'
BEGIN
	INSERT INTO replicate_run_catalog (path, replicate_path, description, status_id, created, cataloged) VALUES (path_to_run, path_to_replicate, description, 1, created_date, NOW());
END$$

CREATE PROCEDURE replicate_with_runs_complete()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return list of replicates with completely analyzed runs'
BEGIN
	SELECT DISTINCT replicate_path FROM replicate_run_catalog WHERE replicate_path NOT IN (SELECT DISTINCT replicate_path FROM replicate_run_catalog AS run INNER JOIN RAW_catalog AS raw ON REPLACE(raw.path, CONCAT('/', SUBSTRING_INDEX(raw.path, '/', -1)), '') = run.path WHERE ISNULL(analyzed));
END$$

CREATE PROCEDURE replicate_raw_files(IN in_replicate_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return list of RAW files for a run'
BEGIN
	SELECT raw.path FROM (SELECT path FROM replicate_run_catalog WHERE replicate_path = in_replicate_path) AS run INNER JOIN RAW_catalog AS raw ON REPLACE(raw.path, CONCAT('/' , SUBSTRING_INDEX(raw.path, '/', -1)), '') = run.path;
END$$

CREATE PROCEDURE condition_replicate_catalog_set_analysis_running(IN path_to_replicate VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set status for condition replicate that analysis is running'
BEGIN
	UPDATE condition_replicate_catalog SET status_id = 2 WHERE path = path_to_replicate;
END$$

CREATE PROCEDURE condition_replicate_catalog_peptide_prophet_job(IN path_to_replicate VARCHAR(1000), IN job_path VARCHAR(1000), IN job_log_datetime DATETIME, IN job_log_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Load peptide prophet job & job log for replicate into catalog'
BEGIN
	UPDATE condition_replicate_catalog SET status_id = 3, peptide_prophet_job=LOAD_FILE(job_path), peptide_prophet=job_log_datetime, peptide_prophet_log=LOAD_FILE(job_log_path) WHERE path = path_to_replicate;
END$$

CREATE PROCEDURE condition_replicate_catalog_protein_prophet_job(IN path_to_replicate VARCHAR(1000), IN job_path VARCHAR(1000), IN job_log_datetime DATETIME, IN job_log_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Load protein prophet job & job log for replicate into catalog'
BEGIN
	UPDATE condition_replicate_catalog SET complete = NOW(), status_id = 4, protein_prophet_job=LOAD_FILE(job_path), protein_prophet=job_log_datetime, protein_prophet_log=LOAD_FILE(job_log_path) WHERE path = path_to_replicate;
END$$

CREATE PROCEDURE conditions_with_analyzed_replicates()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return list of conditions with analyzed replicates'
BEGIN
        SELECT condition_path FROM (SELECT a.condition_path, IF(ISNULL(c), 0, c) AS replicates, IF(ISNULL(d), 0, d) AS replicates_complete FROM (SELECT condition_path, COUNT(*) AS c FROM condition_replicate_catalog GROUP BY condition_path) AS a LEFT JOIN (SELECT condition_path, COUNT(*) AS d FROM condition_replicate_catalog WHERE status_id = 4 GROUP BY condition_path) AS b ON a.condition_path = b.condition_path) AS crrc WHERE replicates_complete = replicates;
END$$

CREATE PROCEDURE replicates_in_condition(IN in_condition_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return list of replicates for a condition'
BEGIN
        SELECT path FROM condition_replicate_catalog WHERE condition_path = in_condition_path;
END$$

CREATE PROCEDURE experiment_condition_analysis_running(IN path_to_condition VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set status for experiment condition that analysis is running'
BEGIN
        UPDATE experiment_condition_catalog SET status_id = 2, analysis = NOW() WHERE path = path_to_condition;
END$$

CREATE PROCEDURE experiment_condition_catalog_job(IN path_to_condition VARCHAR(1000), IN job_path VARCHAR(1000), IN job_log_datetime DATETIME, IN job_log_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Load condition replicate join job and job log into catalog'
BEGIN
        UPDATE experiment_condition_catalog SET status_id = 3, analysis_job=LOAD_FILE(job_path), complete=job_log_datetime, analysis_log=LOAD_FILE(job_log_path) WHERE path = path_to_condition;
END$$

CREATE PROCEDURE experiments_with_complete_conditions()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return list of experiments with complete conditions'
BEGIN
        SELECT experiment_path FROM (SELECT experiment_path, COUNT(*) AS c FROM experiment_condition_catalog WHERE status_id = 3 GROUP BY experiment_path) AS a WHERE c > 1;
END$$

CREATE PROCEDURE complete_conditions_in_experiment(IN in_experiment_path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return list of complete conditions for experiment'
BEGIN
        SELECT path FROM experiment_condition_catalog WHERE status_id = 3 AND experiment_path = in_experiment_path;
END$$

CREATE PROCEDURE get_owner(IN path VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Return owner and email for a RAW or experiment path'
BEGIN
        SELECT owner, email FROM owners WHERE owner = SUBSTRING_INDEX(path, '/', 1);
END$$

DROP PROCEDURE IF EXISTS experiment_delete;

CREATE PROCEDURE experiment_delete(IN experiment_path VARCHAR(256))
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Delete experiment and all dependent data except RAW_catalog'
BEGIN
	START TRANSACTION;
		DELETE replicate_run_catalog, condition_replicate_catalog, experiment_condition_catalog
			FROM replicate_run_catalog 
				INNER JOIN condition_replicate_catalog
				INNER JOIN experiment_condition_catalog
				INNER JOIN experiment_catalog
			WHERE replicate_run_catalog.replicate_path = condition_replicate_catalog.path AND
				condition_replicate_catalog.condition_path = experiment_condition_catalog.path AND
				experiment_condition_catalog.experiment_path = experiment_catalog.path;
		DELETE FROM experiment_catalog WHERE path = experiment_path;
	COMMIT;
END$$

CREATE PROCEDURE RAW_catalog_unarchived()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files to be archived in lolo'
BEGIN
        SELECT path FROM RAW_catalog WHERE RAW_archived = 0 AND status_id >= 2 ORDER BY path;
END$$

CREATE PROCEDURE RAW_catalog_archived(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set the archived flag for the RAW file'
BEGIN
	UPDATE RAW_catalog SET RAW_archived = 1 WHERE path = path_to_RAW;
END$$

CREATE PROCEDURE RAW_catalog_unarchived_mzXML()
LANGUAGE SQL
DETERMINISTIC
SQL SECURITY INVOKER
COMMENT 'Find RAW files to be archived in lolo'
BEGIN
        SELECT path FROM RAW_catalog WHERE mzXML_archived = 0 AND status_id >= 3 ORDER BY path;
END$$

CREATE PROCEDURE RAW_catalog_archived_mzXML(IN path_to_RAW VARCHAR(1000))
LANGUAGE SQL
DETERMINISTIC
MODIFIES SQL DATA
SQL SECURITY INVOKER
COMMENT 'Set the archived flag for the RAW file'
BEGIN
        UPDATE RAW_catalog SET mzXML_archived = 1 WHERE path = path_to_RAW;
END$$

