Describe "Get-JiraIssueAttachment" {

    Import-Module "$PSScriptRoot/../JiraPS" -Force -ErrorAction Stop

    InModuleScope JiraPS {

        . "$PSScriptRoot/Shared.ps1"

        $jiraServer = 'http://jiraserver.example.com'
        $issueID = 41701
        $issueKey = 'IT-3676'

        $attachments = @"
[
    {
        "self": "$jiraServer/rest/api/2/attachment/10013",
        "id": "10013",
        "filename": "foo.pdf",
        "author": {
            "self": "$jiraServer/rest/api/2/user?username=admin",
            "name": "admin",
            "key": "admin",
            "accountId": "000000:000000-0000-0000-0000-ab899c878d00",
            "emailAddress": "admin@example.com",
            "avatarUrls": { },
            "displayName": "Admin",
            "active": true,
            "timeZone": "Europe/Berlin"
        },
        "created": "2017-10-16T10:06:29.399+0200",
        "size": 60444,
        "mimeType": "application/pdf",
        "content": "$jiraServer/secure/attachment/10013/foo.pdf"
    },
    {
        "self": "$jiraServer/rest/api/2/attachment/10010",
        "id": "10010",
        "filename": "bar.pdf",
        "author": {
            "self": "$jiraServer/rest/api/2/user?username=admin",
            "name": "admin",
            "key": "admin",
            "accountId": "000000:000000-0000-0000-0000-ab899c878d00",
            "emailAddress": "admin@example.com",
            "avatarUrls": { },
            "displayName": "Admin",
            "active": true,
            "timeZone": "Europe/Berlin"
        },
        "created": "2017-10-16T09:06:48.070+0200",
        "size": 438098,
        "mimeType": "'application/pdf'",
        "content": "$jiraServer/secure/attachment/10010/bar.pdf"
    }
]
"@

        Mock Get-JiraIssue -ModuleName JiraPS {
            $IssueObj = [PSCustomObject]@{
                ID         = $issueID
                Key        = $issueKey
                RestUrl    = "$jiraServer/rest/api/latest/issue/$issueID"
                attachment = (ConvertFrom-Json2 -InputObject $attachments)
            }
            $IssueObj.PSObject.TypeNames.Insert(0, 'JiraPS.Issue')
            $IssueObj
        }

        Mock Resolve-JiraIssueObject -ModuleName JiraPS {
            Get-JiraIssue -Key $Issue
        }

        Mock ConvertTo-JiraAttachment -ModuleName JiraPS {
            $InputObject
        }

        # Generic catch-all. This will throw an exception if we forgot to mock something.
        Mock Invoke-JiraMethod -ModuleName JiraPS {
            ShowMockInfo 'Invoke-JiraMethod' 'Method', 'Uri'
            throw "Unidentified call to Invoke-JiraMethod"
        }

        #############
        # Tests
        #############

        $issueObject = Get-JiraIssue -Key $issueKey

        It 'only accepts String or JiraPS.Issue as input' {
            { Get-JiraIssueAttachment -Issue (Get-Date) } | Should Throw
            { Get-JiraIssueAttachment -Issue (Get-ChildItem) } | Should Throw
            { Get-JiraIssueAttachment -Issue @('foo', 'bar') } | Should Not Throw
            { Get-JiraIssueAttachment -Issue (Get-JiraIssue -Key "foo") } | Should Not Throw
        }

        It 'takes the issue input over the pipeline' {
            { $issueObject | Get-JiraIssueAttachment } | Should Not Throw
            { $issueKey | Get-JiraIssueAttachment } | Should Not Throw
        }

        It 'converts the attachments to objects' {
            $issueObject | Get-JiraIssueAttachment
            Get-JiraIssueAttachment -Issue $issueKey
            Assert-MockCalled -CommandName ConvertTo-JiraAttachment -Exactly 2 -Scope It
        }

        It 'filters the result by FileName' {
            @($issueObject | Get-JiraIssueAttachment).Count | Should Be 2
            @($issueObject | Get-JiraIssueAttachment -FileName 'foo.pdf').Count | Should Be 1
        }
    }
}