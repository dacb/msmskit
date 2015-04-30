CREATE TEMPORARY TABLE test (
	entry_no			INTEGER,
	group_probability		FLOAT,
	protein				VARCHAR(64),
	protein_link			LONGTEXT,
	protein_probability		FLOAT,
	percent_coverage		FLOAT,
	num_unique_peps			INTEGER,
	tot_indep_spectra		INTEGER,
	percent_share_of_spectrum_ids	FLOAT,
	description			VARCHAR(256),
	protein_molecular_weight	FLOAT,
	protein_length			INTEGER,
	is_nondegenerate_evidence	CHAR(1),
	weight				FLOAT,
	precursor_ion_charge		INTEGER,
	peptide_sequence		VARCHAR(128),
	peptide_link			LONGTEXT,
	nsp_adjusted_probability	FLOAT,
	initial_probability		FLOAT,
	n_tol_termini			INTEGER,
	n_sibling_peptides_bin		INTEGER,
	n_instances			INTEGER,
	peptide_group_designator	CHAR(1),
	INDEX(protein),
	INDEX(protein_probability),
	INDEX(is_nondegenerate_evidence),
	INDEX(nsp_adjusted_probability),
	INDEX(initial_probability)
);
LOAD DATA INFILE '/Volumes/Drobo1/Erik/PgSgFn_Community/Fusobacterium_nucleatum/BioI/interact.prot.xls'
	INTO TABLE test FIELDS TERMINATED BY '\t' LINES TERMINATED BY '\t'
	IGNORE 2 LINES
;
DELETE FROM test WHERE ISNULL(protein);
SELECT protein, protein_probability, tot_indep_spectra FROM test GROUP BY protein;
