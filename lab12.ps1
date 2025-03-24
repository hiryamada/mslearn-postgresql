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

Step 'Generate password for postgres admin user'
$env:PGPASSWORD = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 18 | ForEach-Object {[char]$_})  

Step 'Deploy Azure resources. this will take approximately 5 minutes to complete.
az deployment group create -g $RG_NAME --template-file .\$folder\mslearn-postgresql-main\Allfiles\Labs\Shared\deploy.bicep --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$env:PGPASSWORD

Step 'Define a function to send a SQL query using psql'
$SERVER_FQDN = az postgres flexible-server list --query '[].fullyQualifiedDomainName' -o tsv
Function ExecuteQuery { param([string]$Query) psql -U pgAdmin -h $SERVER_FQDN -d rentals -c $Query }

Step 'Create tables'
ExecuteQuery "CREATE TABLE listings (id int, name varchar(100), description text, property_type varchar(25), room_type varchar(30), price numeric, weekly_price numeric)"  
ExecuteQuery "CREATE TABLE reviews (id int, listing_id int, date date, comments text)"  

Step 'Copy data into tables'
ExecuteQuery "\COPY listings FROM 'main/mslearn-postgresql-main/Allfiles/Labs/Shared/listings.csv' CSV HEADER"
ExecuteQuery "\COPY reviews FROM 'main/mslearn-postgresql-main/Allfiles/Labs/Shared/reviews.csv' CSV HEADER"

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

Step 'Create embeddings'
ExecuteQuery "SELECT id, name, azure_openai.create_embeddings('embedding', description) AS vector FROM listings LIMIT 1"

Step 'Set endpoint and key for Azure AI Language'
ExecuteQuery "SELECT azure_ai.set_setting('azure_cognitive.endpoint', '$LANG_ENDPOINT')"
ExecuteQuery "SELECT azure_ai.set_setting('azure_cognitive.subscription_key', '$AOAI_KEY')"

Step 'Analyze sentiment'
ExecuteQuery "SELECT id, comments, azure_cognitive.analyze_sentiment(comments, 'en') AS sentiment FROM reviews WHERE id in (1, 3)"

