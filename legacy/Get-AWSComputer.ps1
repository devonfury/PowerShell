function Get-AWSComputer
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (           
        #Name of AWS Profile
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string]$ProfileName,

        #NetbiosName of Computer
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string]$ServerName
    )
    
    $ModuleFound = Get-Module | Where Name -eq AWSPowerShell
    
    if($ModuleFound -eq $null)
    {
        try
        {
            Import-Module AWSPowerShell
        }
        catch
        {
            Write-error "Could not load AWSPowerShell module."
            exit
        }        
    }
    
    #Set AWS Profile
    Set-AWSCredentials -ProfileName $AWSProfile

    #Create filter based on Computer Name
    $computer = @{"name"="tag:Name";"values"=$ServerName}

    #Get the EC2 Instance
    try
    {
        $objAws = Get-EC2Instance -filter $computer | Select Instances
        if($objAWS -ne $null)
        {
            $objInstances = $objAws.Instances
            #write-output $objInstances
			#Get the Tags
			$tags = $objInstances.Tags
			$objTags = @()
			foreach($tag in $tags)
			{        
				$tagName = $tag.Key        
				$tagValue = $tag.Value
				switch($tagName)
				{
					"Name"
					{
						$name = $tagValue
						break
					}
					"Business Service"
					{
						$service = $tagValue
						break
					}
					"Application"
					{
						$app = $tagValue
						break
					}
					"App-Env"
					{
						$appEnv = $tagValue
						break
					}
					"Function"
					{
						$function = $tagValue
						break
					}
				}           
			}    
			[pscustomobject] $objAWSComputer = @{"AWSInstance"=$objInstances;"Name"=$name;"BusinessService"=$service;"Application"=$app;"ApplicationEnv"=$appEnv;"Function"=$function}
			write-output $objAWSComputer
        }
        else
        {
            Write-Output "An AWS instance with the name of $ServerName was not found."
            Write-Output $null
        }
    }
    catch
    {
        write-error "Error retrieving AWS instance for $computer"
		Write-Output $null
    }    
}

cls

$objAWSInstance = Get-AWSComputer -ProfileName $profile -ServerName $Server
write-output $objAWSInstance  -Verbose