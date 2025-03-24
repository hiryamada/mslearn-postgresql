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

############# lab 13 original steps #############

Step 'Enable azure_ai extension'
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

Step 'Generate embeddings for a specific text'
ExecuteQuery "SELECT azure_openai.create_embeddings('embedding', 'bright natural light');"

Step 'Find similar id, name from listings'
ExecuteQuery "SELECT id, name FROM listings ORDER BY listing_vector <=> azure_openai.create_embeddings('embedding', 'bright natural light')::vector LIMIT 10;"

Step 'Find similar descriptions from listings'
ExecuteQuery "SELECT id, description FROM listings ORDER BY listing_vector <=> azure_openai.create_embeddings('embedding', 'bright natural light')::vector LIMIT 1;"

