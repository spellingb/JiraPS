function Get-JiraIssue {
    # .ExternalHelp ..\JiraPS-help.xml
    [CmdletBinding( SupportsPaging, DefaultParameterSetName = 'ByIssueKey' )]
    param(
        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByIssueKey' )]
        [ValidateNotNullOrEmpty()]
        [Alias('Issue')]
        [String[]]
        $Key,

        [Parameter( Position = 0, Mandatory, ParameterSetName = 'ByInputObject' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Issue" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $exception = ([System.ArgumentException]"Invalid Type for Parameter") #fix code highlighting]
                    $errorId = 'ParameterType.NotJiraIssue'
                    $errorCategory = 'InvalidArgument'
                    $errorTarget = $_
                    $errorItem = New-Object -TypeName System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $errorTarget
                    $errorItem.ErrorDetails = "Wrong object type provided for Issue. Expected [JiraPS.Issue] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                }
                else {
                    return $true
                }
            }
        )]
        [Object[]]
        $InputObject,
        <#
          #ToDo:Deprecate
          This is not necessary if $Key uses ValueFromPipelineByPropertyName
          #ToDo:CustomClass
          Once we have custom classes, this check can be done with Type declaration
        #>

        [Parameter( Mandatory, ParameterSetName = 'ByJQL' )]
        [Alias('JQL')]
        [String]
        $Query,

        [Parameter( Mandatory, ParameterSetName = 'ByFilter' )]
        [ValidateNotNullOrEmpty()]
        [ValidateScript(
            {
                if (("JiraPS.Filter" -notin $_.PSObject.TypeNames) -and (($_ -isnot [String]))) {
                    $exception = ([System.ArgumentException]"Invalid Type for Parameter") #fix code highlighting]
                    $errorId = 'ParameterType.NotJiraFilter'
                    $errorCategory = 'InvalidArgument'
                    $errorTarget = $_
                    $errorItem = New-Object -TypeName System.Management.Automation.ErrorRecord $exception, $errorId, $errorCategory, $errorTarget
                    $errorItem.ErrorDetails = "Wrong object type provided for Filter. Expected [JiraPS.Filter] or [String], but was $($_.GetType().Name)"
                    $PSCmdlet.ThrowTerminatingError($errorItem)
                    <#
                      #ToDo:CustomClass
                      Once we have custom classes, this check can be done with Type declaration
                    #>
                }
                else {
                    return $true
                }
            }
        )]
        [Object]
        $Filter,

        [Parameter( ParameterSetName = 'ByJQL' )]
        [Parameter( ParameterSetName = 'ByFilter' )]
        [UInt32]
        $StartIndex = 0,

        [Parameter( ParameterSetName = 'ByJQL' )]
        [Parameter( ParameterSetName = 'ByFilter' )]
        [UInt32]
        $MaxResults = 0,

        [Parameter( ParameterSetName = 'ByJQL' )]
        [Parameter( ParameterSetName = 'ByFilter' )]
        [UInt32]
        $PageSize = $script:DefaultPageSize,

        [Parameter()]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty
    )

    begin {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Function started"

        $server = Get-JiraConfigServer -ErrorAction Stop

        $resourceURi = "$server/rest/api/latest/issue/{0}?expand=transitions"
        $searchURi = "$server/rest/api/latest/search"
    }

    process {
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] ParameterSetName: $($PsCmdlet.ParameterSetName)"
        Write-DebugMessage "[$($MyInvocation.MyCommand.Name)] PSBoundParameters: $($PSBoundParameters | Out-String)"

        switch ($PSCmdlet.ParameterSetName) {
            'ByIssueKey' {
                foreach ($_key in $Key) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_key]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_key [$_key]"

                    $parameter = @{
                        URI        = $resourceURi -f $_key
                        Method     = "GET"
                        Credential = $Credential
                    }
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                    $result = Invoke-JiraMethod @parameter

                    Write-Output (ConvertTo-JiraIssue -InputObject $result)
                }
            }
            'ByInputObject' {
                # Write-Warning "[$($MyInvocation.MyCommand.Name)] The parameter '-InputObject' has been marked as deprecated."
                foreach ($_issue in $InputObject) {
                    Write-Verbose "[$($MyInvocation.MyCommand.Name)] Processing [$_issue]"
                    Write-Debug "[$($MyInvocation.MyCommand.Name)] Processing `$_issue [$_issue]"

                    Write-Output (Get-JiraIssue -Key $_issue.Key -Credential $Credential)
                }
            }
            'ByJQL' {
                $parameter = @{
                    URI          = $searchURi
                    Method       = "GET"
                    GetParameter = @{
                        jql           = (ConvertTo-URLEncoded $Query)
                        validateQuery = $true
                        expand        = "transitions"
                        maxResults    = $PageSize
                    }
                    OutputType   = "JiraIssue"
                    Paging       = $true
                    Credential   = $Credential
                }
                # Paging
                ($PSCmdlet.PagingParameters | Get-Member -MemberType Property).Name | ForEach-Object {
                    $parameter[$_] = $PSCmdlet.PagingParameters.$_
                }
                # Make `SupportsPaging` be backwards compatible
                if ($StartIndex) {
                    $parameter["Skip"] = $StartIndex
                }
                if ($MaxResults) {
                    $parameter["First"] = $MaxResults
                }


                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                Invoke-JiraMethod @parameter
            }
            'ByFilter' {
                $filterObj = Get-JiraFilter -InputObject $Filter -Credential $Credential -ErrorAction Stop
                <#
                  #ToDo:CustomClass
                  Once we have custom classes, this will no longer be necessary
                #>

                $parameter = @{
                    URI          = $filterObj.SearchUrl
                    Method       = "GET"
                    GetParameter = @{
                        validateQuery = $true
                        expand        = "transitions"
                        maxResults    = $PageSize
                    }
                    OutputType   = "JiraIssue"
                    Paging       = $true
                    Credential   = $Credential
                }
                # Paging
                ($PSCmdlet.PagingParameters | Get-Member -MemberType Property).Name | ForEach-Object {
                    $parameter[$_] = $PSCmdlet.PagingParameters.$_
                }
                # Make `SupportsPaging` be backwards compatible
                if ($StartIndex) {
                    $parameter["Skip"] = $StartIndex
                }
                if ($MaxResults) {
                    $parameter["First"] = $MaxResults
                }

                Write-Debug "[$($MyInvocation.MyCommand.Name)] Invoking JiraMethod with `$parameter"
                Invoke-JiraMethod @parameter
            }
        }
    }

    end {
        Write-Verbose "[$($MyInvocation.MyCommand.Name)] Complete"
    }
}
