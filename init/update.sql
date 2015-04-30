DROP PROCEDURE IF EXISTS experiment_delete;

DELIMITER $$

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
