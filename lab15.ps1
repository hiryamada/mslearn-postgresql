# Function Step {
# 	param([string]$Text)
# 	Write-Output "#################################"
# 	Write-Output "# $Text"
# 	Write-Output "#################################"
# 	Write-Host "Press Enter to continue:" -NoNewline
# 	Read-Host
# }

function Step ($name, [ScriptBlock]$block) {
	Write-Output "Step '$name':"
	Write-Output ($block.ToString())
	& $block
	Write-Host "Press Enter to continue:" -NoNewline
	Read-Host
}
  
Step 'Create resource group' {
	$Global:REGION = "eastus"
	$Global:RG_NAME = "rg-learn-postgresql-ai-$REGION"
	az group create --name $RG_NAME --location $REGION
}

Step 'Deploy Azure resources. this will take approximately 5 minutes to complete.' {
	$env:PGPASSWORD = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 18 | ForEach-Object {[char]$_})  
	az deployment group create -g $RG_NAME --template-file .\Allfiles\Labs\Shared\deploy.bicep --parameters restore=false adminLogin=pgAdmin adminLoginPassword=$env:PGPASSWORD
}

Step 'Define a function to send a SQL query using psql' {
	$Global:POSTGRES_FQDN = az postgres flexible-server list --query '[].fullyQualifiedDomainName' -o tsv
	Function Global:ExecuteQuery { param([string]$Query) psql -U pgAdmin -h $POSTGRES_FQDN -d rentals -c $Query }	
}

Step 'Create tables' {
	ExecuteQuery "CREATE TABLE listings (id int, name varchar(100), description text, property_type varchar(25), room_type varchar(30), price numeric, weekly_price numeric)"  
	ExecuteQuery "CREATE TABLE reviews (id int, listing_id int, date date, comments text)"  
}

Step 'Copy data into tables' {
	ExecuteQuery "\COPY listings FROM 'Allfiles/Labs/Shared/listings.csv' CSV HEADER"
	ExecuteQuery "\COPY reviews FROM 'Allfiles/Labs/Shared/reviews.csv' CSV HEADER"
}

Step 'Enable vector extension' {
	ExecuteQuery "CREATE EXTENSION vector;"
}

Step 'Enable azure_ai extension' {
	ExecuteQuery "CREATE EXTENSION IF NOT EXISTS azure_ai"
}

Step 'Get Azure AI Services resource info' {
	$Global:AOAI_NAME = az cognitiveservices account list --query '[?kind==`AIServices`].name' -o tsv
	$Global:LANG_ENDPOINT = (az cognitiveservices account show -n $AOAI_NAME -g $RG_NAME --query 'properties.endpoint' -o tsv)
	$Global:AOAI_ENDPOINT = $LANG_ENDPOINT -replace 'cognitiveservices', 'openai'
	$Global:AOAI_KEY = az cognitiveservices account keys list -n $AOAI_NAME -g $RG_NAME --query 'key1' -o tsv
}

Step 'Set endpoint and key for Azure OpenAI' {
	ExecuteQuery "SELECT azure_ai.set_setting('azure_openai.endpoint', '$AOAI_ENDPOINT')"
	ExecuteQuery "SELECT azure_ai.set_setting('azure_openai.subscription_key', '$AOAI_KEY')"
}

Step 'Set endpoint and key for Azure AI Language' {
	ExecuteQuery "SELECT azure_ai.set_setting('azure_cognitive.endpoint', '$LANG_ENDPOINT')"
	ExecuteQuery "SELECT azure_ai.set_setting('azure_cognitive.subscription_key', '$AOAI_KEY')"
}

Step 'Add vector column to listings table' {
	ExecuteQuery "ALTER TABLE listings ADD COLUMN listing_vector vector(1536);"
}

Step 'Create embeddings' {
	ExecuteQuery "UPDATE listings SET listing_vector = azure_openai.create_embeddings('embedding', description, max_attempts => 5, retry_delay_ms => 500) WHERE listing_vector IS NULL;"
}

############# lab 15 original steps #############

Step 'Create extractive summaries' {
	ExecuteQuery "SELECT id, name, description, azure_cognitive.summarize_extractive(description, 'en', 2) AS extractive_summary FROM listings WHERE id IN (1, 2);"
}

Step 'Create abstractive summaries' {
	ExecuteQuery "SELECT id, name, description, azure_cognitive.summarize_abstractive(description, 'en', 2) AS abstractive_summary FROM listings WHERE id IN (1, 2);"
}

Step 'Add summary column to listings table' {
	ExecuteQuery "ALTER TABLE listings ADD COLUMN summary text;"
}

Step 'Create summaries for all the existing properties in the database' {
	psql -U pgAdmin -h $POSTGRES_FQDN -d rentals -f .\lab15_cte.sql
}

Step 'View the summaries written into the listings table' {
	ExecuteQuery "SELECT id, name, description, summary FROM listings LIMIT 5;"
}

Step 'Combines all reviews for a listing into a single string and then generates abstractive summarization over that string' {
	ExecuteQuery "SELECT unnest(azure_cognitive.summarize_abstractive(reviews_combined, 'en')) AS review_summary FROM (SELECT string_agg(comments, ' ') AS reviews_combined FROM reviews WHERE listing_id = 1);"
}
