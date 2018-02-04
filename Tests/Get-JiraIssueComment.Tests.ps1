Import-Module "$PSScriptRoot/../JiraPS" -Force -ErrorAction Stop

InModuleScope JiraPS {
    . "$PSScriptRoot/Shared.ps1"

    Describe "Get-JiraIssueComment" {

        $jiraServer = 'http://jiraserver.example.com'
        $issueID = 41701
        $issueKey = 'IT-3676'

        $restResult = @"
{
    "startAt": 0,
    "maxResults": 1,
    "total": 1,
    "comments": [
        {
            "self": "$jiraServer/rest/api/2/issue/$issueID/comment/90730",
            "id": "90730",
            "body": "Test comment",
            "created": "2015-05-01T16:24:38.000-0500",
            "updated": "2015-05-01T16:24:38.000-0500",
            "visibility": {
                "type": "role",
                "value": "Developers"
            }
        }
    ]
}
"@
        Mock Get-JiraConfigServer -ModuleName JiraPS {
            Write-Output $jiraServer
        }

        Mock Get-JiraIssue -ModuleName JiraPS {
            $object = [PSCustomObject] @{
                ID      = $issueID
                Key     = $issueKey
                RestUrl = "$jiraServer/rest/api/latest/issue/$issueID"
            }
            $object.PSObject.TypeNames.Insert(0, 'JiraPS.Issue')
            return $object
        }

        Mock Resolve-JiraIssueObject -ModuleName JiraPS {
            Get-JiraIssue -Key $Issue
        }

        # Obtaining comments from an issue...this is IT-3676 in the test environment
        Mock Invoke-JiraMethod -ModuleName JiraPS -ParameterFilter {$Method -eq 'Get' -and $URI -eq "$jiraServer/rest/api/latest/issue/$issueID/comment"} {
            ShowMockInfo 'Invoke-JiraMethod' 'Method', 'Uri'
            ConvertFrom-Json2 -InputObject $restResult
        }

        # Generic catch-all. This will throw an exception if we forgot to mock something.
        Mock Invoke-JiraMethod -ModuleName JiraPS {
            ShowMockInfo 'Invoke-JiraMethod' 'Method', 'Uri'
            throw "Unidentified call to Invoke-JiraMethod"
        }

        #############
        # Tests
        #############

        It "Obtains all Jira comments from a Jira issue if the issue key is provided" {
            $comments = Get-JiraIssueComment -Issue $issueKey
            $comments | Should Not BeNullOrEmpty
            @($comments).Count | Should Be 1
            $comments.ID | Should Be 90730
            $comments.Body | Should Be 'Test comment'
            $comments.RestUrl | Should Be "$jiraServer/rest/api/2/issue/$issueID/comment/90730"

            # Get-JiraIssue should be called to identify the -Issue parameter
            Assert-MockCalled -CommandName Get-JiraIssue -ModuleName JiraPS -Exactly -Times 1 -Scope It

            # Normally, this would be called once in Get-JiraIssue and a second time in Get-JiraIssueComment, but
            # since we've mocked Get-JiraIssue out, it will only be called once.
            Assert-MockCalled -CommandName Invoke-JiraMethod -ModuleName JiraPS -Exactly -Times 1 -Scope It
        }

        It "Obtains all Jira comments from a Jira issue if the Jira object is provided" {
            $issue = Get-JiraIssue -Key $issueKey
            $comments = Get-JiraIssueComment -Issue $issue
            $comments | Should Not BeNullOrEmpty
            $comments.ID | Should Be 90730
            Assert-MockCalled -CommandName Invoke-JiraMethod -ModuleName JiraPS -Exactly -Times 1 -Scope It
        }

        It "Handles pipeline input from Get-JiraIssue" {
            $comments = Get-JiraIssue -Key $issueKey | Get-JiraIssueComment
            $comments | Should Not BeNullOrEmpty
            $comments.ID | Should Be 90730
            Assert-MockCalled -CommandName Invoke-JiraMethod -ModuleName JiraPS -Exactly -Times 1 -Scope It
        }
    }
}
