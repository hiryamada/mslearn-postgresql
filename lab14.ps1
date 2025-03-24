Function Step {
	param([string]$Text)
	Write-Output "#################################"
	Write-Output "# $Text"
	Write-Output "#################################"
	Write-Host "Press Enter to continue:" -NoNewline
	Read-Host
}

Step 'Create resource group'
$REGION = "eastus"
$RG_NAME = "rg-learn-postgresql-ai-$REGION"
az group create --name $RG_NAME --location $REGION

Step 'Deploy Azure resources. this will take approximately 5 minutes to complete.'
$env:PGPASSWORD = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 18 | ForEach-Object {[char]$_})  
az deployment group create -g $RG_NAME --template-file .\Allfiles\Labs\Shared\deploy.bicep --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$env:PGPASSWORD

Step 'Define a function to send a SQL query using psql'
$POSTGRES_FQDN = az postgres flexible-server list --query '[].fullyQualifiedDomainName' -o tsv
Function ExecuteQuery { param([string]$Query) psql -U pgAdmin -h $POSTGRES_FQDN -d rentals -c $Query }

Step 'Create tables'
ExecuteQuery "CREATE TABLE listings (id int, name varchar(100), description text, property_type varchar(25), room_type varchar(30), price numeric, weekly_price numeric)"  
ExecuteQuery "CREATE TABLE reviews (id int, listing_id int, date date, comments text)"  

Step 'Copy data into tables'
ExecuteQuery "\COPY listings FROM 'Allfiles/Labs/Shared/listings.csv' CSV HEADER"
ExecuteQuery "\COPY reviews FROM 'Allfiles/Labs/Shared/reviews.csv' CSV HEADER"


Step 'Enable vector extension'
ExecuteQuery "CREATE EXTENSION vector;"

Step 'Enable azure_ai extension'
ExecuteQuery "CREATE EXTENSION IF NOT EXISTS azure_ai"

Step 'Get Azure AI Services resource info'
$AOAI_NAME = az cognitiveservices account list --query '[?kind==`AIServices`].name' -o tsv
$LANG_ENDPOINT = (az cognitiveservices account show -n $AOAI_NAME -g $RG_NAME --query 'properties.endpoint' -o tsv)
$AOAI_ENDPOINT = $LANG_ENDPOINT -replace 'cognitiveservices', 'openai'
$AOAI_KEY = az cognitiveservices account keys list -n $AOAI_NAME -g $RG_NAME --query 'key1' -o tsv

Step 'Set endpoint and key for Azure OpenAI'
ExecuteQuery "SELECT azure_ai.set_setting('azure_openai.endpoint', '$AOAI_ENDPOINT')"
ExecuteQuery "SELECT azure_ai.set_setting('azure_openai.subscription_key', '$AOAI_KEY')"

Step 'Add vector column to listings table'
ExecuteQuery "ALTER TABLE listings ADD COLUMN listing_vector vector(1536);"

Step 'Create embeddings'
ExecuteQuery "UPDATE listings SET listing_vector = azure_openai.create_embeddings('embedding', description, max_attempts => 5, retry_delay_ms => 500) WHERE listing_vector IS NULL;"

############# lab 14 original steps #############

Step 'Create recommended_listing function'
psql -U pgAdmin -h $POSTGRES_FQDN -d rentals -f .\lab14_recommended_listing.sql

Step 'search for 20 listing recommendations closest to a listing'
ExecuteQuery "select out_listingName, out_score from recommend_listing( (SELECT id from listings limit 1), 20);"
