function Get-SQLBrowserService
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (           
        #Name of computer with SQL
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string]$ServerName
    )
       
    try
    {
        write-verbose -Message "Querying SQLBrowser Service on $ServerName"
        $objService = Get-Service -ComputerName $ServerName -Name 'SQLBrowser' | Select Status -Verbose
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"=$objService.Status.ToString()}
    }
    catch [NoServiceFoundForGivenName]
    {
        write-verbose "SQLBrowser service not found on server $ServerName"
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"="NA"}    
    }
    catch
    {
        write-verbose -Message "Unable to query SQLBrowser Service on $ServerName"
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"="Error"}
    }

    write-output $objComputer
}

function Start-SQLBrowserService
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (           
        #Name of computer with SQL
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string]$ServerName
    )
    
    try
    {
        write-verbose -Message "Starting SQLBrowser Service on $ServerName"
        Start-Service -ComputerName $ServerName -Name 'SQLBrowser'
        $objComputer = Get-SQLBrowserService -ServerName $ServerName -verbose
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"=$objComputer.Status}
        if($objComputer.Status = "Running")
        {
            write-verbose -Message "Successfuly started SQL Service on $ServerName"
        }
        else
        {
            throw "Unable to start SQLBrowser Service on $ServerName"            
        }
    }
    catch
    {
        write-verbose -Message "Unable to start SQLBrowser Service on $ServerName"
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"=$null}
    }

    write-output $objComputer
}

function Stop-SQLBrowserService
{
    
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (           
        #Name of computer with SQL
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string]$ServerName
    )
    
    try
    {
        write-verbose -Message "Stopping SQLBrowser Service on $ServerName"
        Stop-Service -ComputerName $ServerName -Name 'SQLBrowser'
        $objComputer = Get-SQLBrowserService -ServerName $ServerName -verbose
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"=$objComputer.Status}
        if($objComputer.Status = "Stopped")
        {
            write-verbose -Message "Successfuly stopped SQL Service on $ServerName"
        }
        else
        {
            throw "Unable to stop SQLBrowser Service on $ServerName"
            
        }
    }
    catch
    {
        write-verbose -Message "Unable to stop SQLBrowser Service on $ServerName"
        [pscustomobject] $objComputer = @{"ServerName"=$ServerName;"Service"="SQLBrowser";"Status"=$null}
    }

    write-output $objComputer    
}

function Get-SQLDB
{
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (           
        #Name of computer with SQL
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [string]$ServerName
    )
    
    
    Import-Module 'C:\Program Files\Microsoft SQL Server\110\Tools\PowerShell\Modules\SQLPS\SQLPS.PSD1' -DisableNameChecking

    $databaseCollection = @()
    
    Set-Location "SQLSERVER:\SQL"
    Set-Location "SQLSERVER:$ServerName"
    $dbInstances = Get-ChildItem
    #write-output $dbInstances
    
    foreach($dbInstance in $dbInstances)
    {
        foreach($db in $dbInstance.Databases)
        {
            $databaseCollection += $db
        }        
    }
    write-output $databaseCollection
    
    Set-Location "C:\"
    Remove-Module "SQLPS"
}

#region Main

function Query-SQLDatabases
{    
    
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param
    (           
        #Name of computer with SQL
        [Parameter(Mandatory=$false,ValueFromPipeLine=$true,Position=0)]
        [ValidateNotNullOrEmpty()] 
        [string]$ServerName,

        #Path to CSV
        [Parameter(Mandatory=$false)]
        [ValidateScript({Test-Path -Path $_})] 
        [string]$CSVPath,
                
        #PS Credentials that can perform Remote PowerShell
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()] 
        [pscredential]$AdminCreds
    )    
    
    begin
    {
       
    }
    
    process
    {               
        foreach ($server in $ServerName )
        {
            #Get SQL Browser Service Status
            $objSQLBrowser = Get-SQLBrowserService -ServerName $server -verbose                                

            if ($objSQLBrowser.Status -ne "Error") 
			{
                if($objSQLBrowser.Status -eq "Stopped")
                {
                    #Start the service
                    $objSQLStart = Start-SQLBrowserService -ServerName $server -verbose                    
                }
                
                #Get SQL Databases
                $objDatabases = Get-SQLDB -ServerName $server -Verbose
                
                if($objSQLStart.Status -eq "Running")
                {
                    #Stop SQL Browsers Service
                    Stop-SQLBrowserService -ServerName $server -verbose
                }
            }
            
            foreach ($DB in $objDatabases)
            {
                $NewDatabaseProperties = @{
                    'Name' = $DB.Parent.Name;
                    'Id' = [string]$([guid]::NewGUID());
                    'HostName' = $server;
                    'InstanceName' = $DB.Parent.InstanceName;
                    'DatabaseName' = $DB.Name;
                    'Environment' = ' ';
                    'Application' = ' ';
                    'DatabaseEngine' = 'MSSQL';
                    'EngineVersion' = $DB.Parent.Version;
                    'AssetStatus' = $true;
                }
                $NewRecord = New-Object -TypeName PSObject -Property $NewDatabaseProperties;
                write-output $NewRecord                
            }            
        }#end foreach    
    }#end process

    end
    {
       
    }
} 
#endregion