configfile:"/home/ubuntu/data/belson/isangi_nanopore/qc/scripts/isangiConfig.yaml"
sampleDir = ['/home/ubuntu/data/phil/salmonella_samples/20210205_1324_MC-110370_0_FAO37531_76db0abb']
#samples = ['CAAWCD','CHF10J2']
samples = ['CAAWCD']
illumina = ['/home/ubuntu/data/phil/salmonella_samples/illumina']
reads = ['17761-33892_1_65','17764-33892_1_77']
results = ['/home/ubuntu/data/belson/isangi_nanopore/qc/results/analysis/2021.05.14']
rule all:
        input:
                expand('{results}/{sample}Amrfinder',results = results,sample = samples),
                expand('{results}/{sample}Bakta',results = results,sample = samples)

rule flye:
	input:
		expand('{sampleDir}/{sample}',sampleDir = sampleDir,sample = samples)
	output:
                directory('{results}/{sample}Flye')
	shell:
                'flye --nano-raw {input}/{wildcards.sample}.fastq -g 5m -o {output} -t 8 --plasmids'

rule polishFlye:
	input:
                r1 = expand('{illumina}/{reads}_bbduk_1.fastq.gz',illumina = illumina,reads = reads),
                r2 = expand('{illumina}/{reads}_bbduk_2.fastq.gz',illumina = illumina,reads = reads),
		gen = rules.flye.output
	output:
		directory('{results}/polishFlyeResults')
	shell:
		"polca.sh -a {input.gen}/assembly.fasta -r '{input.r1} {input.r2}' && mkdir {output} && mv assembly.fasta* {output}"

rule raconX1:
	input:
		rules.flye.output
	output:
		racon1 = temp('{results}/{sample}RaconX1.fasta'),
		paf1 = temp('{results}/{sample}.racon.paf')
	shell:
		'minimap2 -x map-ont {input}/assembly.fasta {rules.flye.input} > {output.paf1} && racon -t 4 {rules.flye.input} {output.paf1} {input}/assembly.fasta > {output.racon1}'

rule polishRaconX1:
	input:
		rules.raconX1.output.racon1
	output:
		directory('{results}/polishRaconX1Results')
	shell:
		"polca.sh -a {input} -r '{rules.polishFlye.input.r1} {rules.polishFlye.input.r2}' && mkdir {output} && mv {wildcards.sample}RaconX1.fasta* {output}"

rule raconX2:
	input:
		rules.raconX1.output.racon1
	output:
		racon2 = temp('{results}/{sample}RaconX2.fasta'),
		paf2 = temp('{results}/{sample}.racon2.paf')
	shell:
                'minimap2 -x map-ont {input} {rules.flye.input} > {output.paf2} && racon -t 4 {rules.flye.input} {output.paf2} {input} > {output.racon2}'

rule polishRaconX2:
	input:
		rules.raconX2.output.racon2
	output:
		directory('{results}/polishRaconX2Results')
	shell:
		"polca.sh -a {input} -r '{rules.polishFlye.input.r1} {rules.polishFlye.input.r2}' && mkdir {output} && mv {wildcards.sample}RaconX2.fasta* {output}"
rule raconX3:
	input:
		rules.raconX2.output.racon2 
	output:
                racon3 = temp('{results}/{sample}RaconX3.fasta'),
		paf3 = temp('{results}/{sample}.racon3.paf')
	shell:
                'minimap2 -x map-ont {input} {rules.flye.input} > {output.paf3} && racon -t 4 {rules.flye.input} {output.paf3} {input} > {output.racon3}'

rule polishRaconX3:
	input:
		rules.raconX3.output.racon3
	output:
		directory('{results}/polishRaconX3Results')
	shell:
		"polca.sh -a {input} -r '{rules.polishFlye.input.r1} {rules.polishFlye.input.r2}' && mkdir {output} && mv {wildcards.sample}RaconX3.fasta* {output}"
rule raconX4:
	input:
		rules.raconX3.output.racon3
	output:
                racon4 = '{results}/{sample}RaconX4.fasta',
		paf4 = temp('{results}/{sample}.racon4.paf')
	shell:
                'minimap2 -x map-ont {input} {rules.flye.input} > {output.paf4} && racon -t 4 {rules.flye.input} {output.paf4} {input} > {output.racon4}'

rule polishRaconX4:
	input:
		rules.raconX4.output.racon4
	output:
		directory('{results}/polishRaconX4Results')
	shell:
		"polca.sh -a {input} -r '{rules.polishFlye.input.r1} {rules.polishFlye.input.r2}' && mkdir {output} && mv {wildcards.sample}RaconX4.fasta* {output}"
rule medaka:
	input:
		rules.raconX4.output.racon4
	output:
		directory('{results}/{sample}Medaka')
	conda:
		'/home/ubuntu/data/belson/isangi_nanopore/qc/scripts/envs/medaka.yml'
	shell:
		'medaka_consensus -i {rules.flye.input} -d {input} -t 8  -m r941_min_high_g360 -o {output}'

rule polishMedaka:
	input:
		rules.medaka.output
	output:
		directory('{results}/polishMedakaResults')
	shell:
		"polca.sh -a {input}/consensus.fasta -r'{rules.polishFlye.r1} {rules.polishFlye.r2}' && mkdir {output} && mv consensus.fasta* {output}"
rule circlator:
	input:
		rules.medaka.output
	output:
		directory('{results}/{sample}Circularised')
	shell:
		'circlator all --merge_min_id 85 --merge_breaklen 1000 {input}/*.fasta {rules.flye.input} {output}'


rule amrfinder:
	input:
		rules.circlator.output

	output:
		'{results}/{sample}Amrfinder'
	shell:
		'amrfinder --plus -n {input}/06.fixstart.fasta -O Salmonella > {output}'

rule bakta:
	input:
		rules.circlator.output
	output:
		directory('{results}/{sample}Bakta')
	shell:
		'./bakta.sh {input}/06.fixstart.fasta {output}'
#rule prokka:
#	input:
#		rules.circlator.output
#	output:
#		directory('{results}/{sample}Prokka')
#	conda:
#		'/home/ubuntu/data/belson/isangi_nanopore/qc/scripts/envs/prokka.yml'
#	shell:
#		'prokka {input}/06.fixstart.fasta --prefix {wildcards.sample} --genus Salmonella --species enterica --outdir {output}'
	
