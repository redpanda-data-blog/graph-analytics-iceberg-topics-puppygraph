#!/bin/bash

table_array=("Account" "AccountRepayLoan" "AccountTransferAccount" "AccountWithdrawAccount" "Company" "CompanyApplyLoan" "CompanyGuaranteeCompany" "CompanyInvestCompany" "CompanyOwnAccount" "Loan" "LoanDepositAccount" "Medium" "MediumSignInAccount" "Person" "PersonApplyLoan" "PersonGuaranteePerson" "PersonInvestCompany" "PersonOwnAccount")

function topic_delete
{
	for table_name in "${table_array[@]}"; do
		echo "Delete topic $table_name";
		rpk topic delete $table_name;
		rpk registry schema delete "$table_name-value" --schema-version latest;
	done
}

function topic_create
{
	for table_name in "${table_array[@]}"; do
		echo "Create topic $table_name";
		rpk topic create "$table_name"  --topic-config="redpanda.iceberg.mode=value_schema_id_prefix";
		rpk registry schema create "$table_name-value" --schema "schemas/$table_name.avsc";
	done
}

function topic_import_snapshot_data
{
	for file in $1/*.txt; do
		table_name=$(basename $file .txt);
		echo "Import snapshot data for $table_name";
		rpk topic produce "$table_name" --schema-id=topic < $file;
	done 
}

function topic_import_incremental_data
{
	echo "Import incremental data";
	while IFS= read -r line; do
		table_name=$(echo $line | cut -d':' -f1)
		msg=$(echo $line | cut -d':' -f2-)
		echo $msg | rpk topic produce "$table_name" --schema-id=topic;
		sleep $2;
	done < $1
}

if [ $# -eq 0 ]; then
    echo "Error: At least one option is required" >&2
    echo "Usage: $0 [-d] [-c] [-s] [-i]" >&2
    echo "  -d: delete topics" >&2
    echo "  -c: create topics" >&2
    echo "  -s: import snapshot data" >&2
    echo "  -i: import incremental data" >&2
    exit 1
fi
	
while getopts "dcsi" opt; do
    case $opt in
        d)
            topic_delete
            ;;
        c)
            topic_create
            ;;
        s)
            topic_import_snapshot_data "data/snapshot_data/"
            ;;
        i)
            topic_import_incremental_data "data/incremental_data.txt" 0.01
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
        :)
            echo "Option -$OPTARG requires an argument." >&2
            exit 1
            ;;
    esac
done