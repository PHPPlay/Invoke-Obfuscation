#    This file is part of Invoke-Obfuscation.
#
#   Copyright 2016 Daniel Bohannon <@danielhbohannon>
#         while at Mandiant <http://www.mandiant.com>
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.



Function Out-ObfuscatedTokenCommand
{
<#
.SYNOPSIS

Master function that orchestrates the tokenization and application of all token-based obfuscation functions to provided PowerShell script.

Invoke-Obfuscation Function: Out-ObfuscatedTokenCommand
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedTokenCommand orchestrates the tokenization and application of all token-based obfuscation functions to provided PowerShell script and places obfuscated tokens back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. If no $TokenTypeToObfuscate is defined then Out-ObfuscatedTokenCommand will automatically perform ALL token obfuscation functions in random order at the highest obfuscation level.

.PARAMETER ScriptBlock

Specifies a scriptblock containing your payload.

.PARAMETER Path

Specifies the path to your payload.

.PARAMETER TokenTypeToObfuscate

(Optional) Specifies the token type to obfuscate ('Member', 'Command', 'CommandArgument', 'String', 'Variable', 'RandomWhitespace', 'Comment'). If not defined then Out-ObfuscatedTokenCommand will automatically perform ALL token obfuscation functions in random order at the highest obfuscation level.

.PARAMETER ObfuscationLevel

(Optional) Specifies the obfuscation level for the given TokenTypeToObfuscate. If not defined then Out-ObfuscatedTokenCommand will automatically perform obfuscation function at the highest available obfuscation level. 
Each token has different available obfuscation levels:
'Argument' 1-3
'Command' 1-2
'Comment' 1
'Member' 1-3
'String' 1
'Variable' 1
'Whitespace' 1

.EXAMPLE

C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'Command' 2

&("WrI"+"t"+"e-H"+"osT") 'Hello World!' -ForegroundColor Green; .("W"+"rITE-hO"+"S"+"t") 'Obfuscation Rocks!' -ForegroundColor Green

.NOTES

Out-ObfuscatedTokenCommand orchestrates the tokenization and application of all token-based obfuscation functions to provided PowerShell script and places obfuscated tokens back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. If no $TokenTypeToObfuscate is defined then Out-ObfuscatedTokenCommand will automatically perform ALL token obfuscation functions in random order at the highest obfuscation level.
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding( DefaultParameterSetName = 'FilePath')] Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ParameterSetName = 'ScriptBlock')]
        [ValidateNotNullOrEmpty()]
        [ScriptBlock]
        $ScriptBlock,

        [Parameter(Position = 0, ParameterSetName = 'FilePath')]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [ValidateSet('Member', 'Command', 'CommandArgument', 'String', 'Variable', 'RandomWhitespace', 'Comment')]
        [Parameter(Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]
        $TokenTypeToObfuscate,

        [Parameter(Position = 2)]
        [ValidateNotNullOrEmpty()]
        [Int]
        $ObfuscationLevel = 10 # Default to highest obfuscation level if $ObfuscationLevel isn't defined
    )

    # Either convert ScriptBlock to a String or convert script at $Path to a String.
    If($PSBoundParameters['Path'])
    {
        Get-ChildItem $Path -ErrorAction Stop | Out-Null
        $ScriptString = [IO.File]::ReadAllText((Resolve-Path $Path))
    }
    Else
    {
        $ScriptString = [String]$ScriptBlock
    }
    
    # If $TokenTypeToObfuscate was not defined then we will automate randomly calling all available obfuscation functions in Out-ObfuscatedTokenCommand.
    If($TokenTypeToObfuscate.Length -eq 0)
    {
        # All available obfuscation token types (minus 'String') currently supported in Out-ObfuscatedTokenCommand.
        # 'Comment' and 'String' will be manually added first and second respectively for reasons defined below.
        # 'RandomWhitespace' will be manually added last for reasons defined below.
        $ObfuscationChoices  = @()
        $ObfuscationChoices += 'Member'
        $ObfuscationChoices += 'Command'
        $ObfuscationChoices += 'CommandArgument'
        $ObfuscationChoices += 'Variable'
        # Commented out Type token obfuscation since it errors after PS 2.0 (i.e. [In`T][C`har]123 works in PS2.0 but not in later versions)
        #$ObfuscationChoices += 'Type'
        
        # Create new array with 'String' plus all obfuscation types above in random order. 
        $ObfuscationTypeOrder = @()
        # Run 'Comment' first since it will be the least number of tokens to iterate through, and comments may be introduced as obfuscation technique in future revisions.
        $ObfuscationTypeOrder += 'Comment'
        # Run 'String' second since otherwise we will have unnecessary command bloat since other obfuscation functions create additional strings.
        $ObfuscationTypeOrder += 'String'
        $ObfuscationTypeOrder += (Get-Random -Input $ObfuscationChoices -Count $ObfuscationChoices.Count)
        # Run 'RandomWhitespace' last so we have the maximum number of operators available from previous obfuscation.
        $ObfuscationTypeOrder += 'RandomWhitespace'

        # Apply each randomly-ordered $ObfuscationType from above step.
        ForEach($ObfuscationType in $ObfuscationTypeOrder) 
        {
            $ScriptString = Out-ObfuscatedTokenCommand ([ScriptBlock]::Create($ScriptString)) $ObfuscationType $ObfuscationLevel
        }
        Return $ScriptString
    }

    # Parse out and obfuscate tokens (in reverse to make indexes simpler for adding in obfuscated tokens).
    $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null)
    
    # Handle fringe case of retrieving count of all tokens used when applying random whitespace.
    $TokenCount = ([System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq $TokenTypeToObfuscate}).Count
    $TokensForInsertingWhitespace = @('Operator','GroupStart','GroupEnd','StatementSeparator')
    If($TokenTypeToObfuscate -eq 'RandomWhitespace')
    {
        # If $TokenTypeToObfuscate='RandomWhitespace' then calculate $TokenCount for output by adding token count for all tokens in $TokensForInsertingWhitespace.
        $TokenCount = 0
        ForEach($TokenForInsertingWhitespace in $TokensForInsertingWhitespace)
        {
            $TokenCount += ([System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq $TokenForInsertingWhitespace}).Count
        }
    }
    # Handle fringe case of outputting verbiage consistent with options presented in Invoke-Obfuscation.
    If($TokenCount -gt 0)
    {
        # To be consistent with verbiage in Invoke-Obfuscation we will print Argument/Whitespace instead of CommandArgument/RandomWhitespace.
        $TokenTypeToObfuscateToPrint = $TokenTypeToObfuscate
        If($TokenTypeToObfuscateToPrint -eq 'CommandArgument')  {$TokenTypeToObfuscateToPrint = 'Argument'}
        If($TokenTypeToObfuscateToPrint -eq 'RandomWhitespace') {$TokenTypeToObfuscateToPrint = 'Whitespace'}
        If($TokenCount -gt 1) {$Plural = 's'}
        Else {$Plural = ''}

        # Output verbiage concerning which $TokenType is currently being obfuscated and how many tokens of each type are left to obfuscate.
        # This becomes more important when obfuscated large scripts where obfuscation can take several minutes due to all of the randomization steps.
        Write-Host "`n[*] Obfuscating $($TokenCount)" -NoNewLine
        Write-Host " $TokenTypeToObfuscateToPrint" -NoNewLine -ForegroundColor Yellow
        Write-Host " token$Plural."
    }

    # Variables for outputting status of token processing for large token counts when obfuscating large scripts.
    $Counter = $TokenCount
    $OutputCount = 0
    $IterationsToOutputOn = 100
    $DifferenceForEvenOutput = $TokenCount % $IterationsToOutputOn
    
    For($i=$Tokens.Count-1; $i -ge 0; $i--)
    {
        $Token = $Tokens[$i]

        # Extra output for large scripts with several thousands tokens (like Invoke-Mimikatz).
        If(($TokenCount -gt $IterationsToOutputOn*2) -AND ((($TokenCount-$Counter)-($OutputCount*$IterationsToOutputOn)) -eq ($IterationsToOutputOn+$DifferenceForEvenOutput)))
        {
            $OutputCount++
            $ExtraWhitespace = ' '*(([String]($TokenCount)).Length-([String]$Counter).Length)
            If($Counter -gt 0)
            {
                Write-Host "[*]             $ExtraWhitespace$Counter" -NoNewLine
                Write-Host " $TokenTypeToObfuscateToPrint" -NoNewLine -ForegroundColor Yellow
                Write-Host " tokens remaining to obfuscate."
            }
        }

        $ObfuscatedToken = ""

        If(($Token.Type -eq 'String') -AND ($TokenTypeToObfuscate.ToLower() -eq 'string')) 
        {
            $Counter--

            # If String $Token immediately follows a period (and does not begin $ScriptString) then do not obfuscate as a String.
            # In this scenario $Token is originally a Member token that has quotes added to it.
            # E.g. both InvokeCommand and InvokeScript in $ExecutionContext.InvokeCommand.InvokeScript
            If(($Token.Start -gt 0) -AND ($ScriptString.SubString($Token.Start-1,1) -eq '.'))
            {
                Continue
            }
            
            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1}  

            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-ObfuscatedStringTokenLevel1 $ScriptString $Token}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }

        }
        ElseIf(($Token.Type -eq 'Member') -AND ($TokenTypeToObfuscate.ToLower() -eq 'member')) 
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1,2,3)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1}

            # The below Parameter Attributes cannot be obfuscated like other Member Tokens, so we will only randomize the case of these tokens.
            # Source 1: https://technet.microsoft.com/en-us/library/hh847743.aspx
            $MemberTokensToOnlyRandomCase   = @()
            $MemberTokensToOnlyRandomCase += 'mandatory'
            $MemberTokensToOnlyRandomCase += 'position'
            $MemberTokensToOnlyRandomCase += 'parametersetname'
            $MemberTokensToOnlyRandomCase += 'valuefrompipeline'
            $MemberTokensToOnlyRandomCase += 'valuefrompipelinebypropertyname'
            $MemberTokensToOnlyRandomCase += 'valuefromremainingarguments'
            $MemberTokensToOnlyRandomCase += 'helpmessage'
            $MemberTokensToOnlyRandomCase += 'alias'
            # Source 2: https://technet.microsoft.com/en-us/library/hh847872.aspx
            $MemberTokensToOnlyRandomCase += 'confirmimpact'
            $MemberTokensToOnlyRandomCase += 'defaultparametersetname'
            $MemberTokensToOnlyRandomCase += 'helpuri'
            $MemberTokensToOnlyRandomCase += 'supportspaging'
            $MemberTokensToOnlyRandomCase += 'supportsshouldprocess'
            $MemberTokensToOnlyRandomCase += 'positionalbinding'

            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-RandomCaseRandomQuotes $ScriptString $Token}
                2 {$ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token}
                3 {$ScriptString = Out-ObfuscatedMemberTokenLevel3 $ScriptString $Tokens $i}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }
        ElseIf(($Token.Type -eq 'CommandArgument') -AND ($TokenTypeToObfuscate.ToLower() -eq 'commandargument')) 
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1,2,3)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1} 
            
            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-RandomCaseRandomQuotes $ScriptString $Token}
                2 {$ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token}
                3 {$ScriptString = Out-ObfuscatedCommandArgumentTokenLevel3 $ScriptString $Token}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }
        ElseIf(($Token.Type -eq 'Command') -AND ($TokenTypeToObfuscate.ToLower() -eq 'command')) 
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1,2)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1}

            # If a variable is encapsulated in curly braces (e.g. ${ExecutionContext}) then the string inside is treated as a Command token.
            # So we will force tick obfuscation (option 1) instead of splatting (option 2) as that would cause errors.
            If(($Token.Start -gt 1) -AND ($ScriptString.SubString($Token.Start-1,1) -eq '{') -AND ($ScriptString.SubString($Token.Start+$Token.Length,1) -eq '}'))
            {
                $ObfuscationLevel = 1
            }
            
            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token}
                2 {$ScriptString = Out-ObfuscatedCommandTokenLevel2 $ScriptString $Token}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }
        ElseIf(($Token.Type -eq 'Variable') -AND ($TokenTypeToObfuscate.ToLower() -eq 'variable'))
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1} 
            
            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-ObfuscatedVariableTokenLevel1 $ScriptString $Token}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }
        <#
        # Commented out Type token obfuscation since it errors after PS 2.0 (i.e. [In`T][C`har]123 works in PS2.0 but not in later versions)
        ElseIf(($Token.Type -eq 'Type') -AND ($TokenTypeToObfuscate.ToLower() -eq 'type')) 
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1} 
            
            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-ObfuscatedTypeTokenLevel1 $ScriptString $Token}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }
        #>
        ElseIf(($TokensForInsertingWhitespace -Contains $Token.Type) -AND ($TokenTypeToObfuscate.ToLower() -eq 'randomwhitespace')) 
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1} 

            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-RandomWhitespace $ScriptString $Tokens $i}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }
        ElseIf(($Token.Type -eq 'Comment') -AND ($TokenTypeToObfuscate.ToLower() -eq 'comment'))
        {
            $Counter--

            # Set valid obfuscation levels for current token type.
            $ValidObfuscationLevels = @(0,1)
            
            # If invalid obfuscation level is passed to this function then default to highest obfuscation level available for current token type.
            If($ValidObfuscationLevels -NotContains $ObfuscationLevel) {$ObfuscationLevel = $ValidObfuscationLevels | Sort-Object -Descending | Select-Object -First 1} 
            
            Switch($ObfuscationLevel)
            {
                0 {Continue}
                1 {$ScriptString = Out-RemoveComments $ScriptString $Token}
                default {Write-Error "An invalid `$ObfuscationLevel value ($ObfuscationLevel) was passed to switch block for token type $($Token.Type)."; Exit;}
            }
        }    
    }

    Return $ScriptString
}


Function Out-ObfuscatedStringTokenLevel1
{
<#
.SYNOPSIS

Obfuscates string token by randomly concatenating the string in-line.

Invoke-Obfuscation Function: Out-ObfuscatedStringTokenLevel1
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedStringTokenLevel1 obfuscates a given string token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'String'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-ObfuscatedStringTokenLevel1 $ScriptString $Token}
C:\PS> $ScriptString

Write-Host ( 'Hel'+'lo W'+'orl'+'d!' ) -ForegroundColor Green; Write-Host (  'Obf'+'uscatio'+'n Roc'+'k'+'s'+'!'  ) -ForegroundColor Green

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'String' 1
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,

        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )

    # Do nothing if the token has length <= 1 (e.g. Write-Host "", single-character tokens, etc.).
    If($Token.Content.Length -le 1) {Return $ScriptString}

    # If the Token is 'invoke' then do nothing. This is because .invoke() is treated as a member but ."invoke"() is treated as a string.
    If($Token.Content.ToLower() -eq 'invoke') {Return $ScriptString}

    # If ticks are already present in current Token then remove so they will not interfere with string concatenation.
    $TokenContent = $Token.Content
    If($Token.Content.Contains('`')) {$TokenContent = $Token.Content.Replace('`','')}

    # Use whichever quote (single- or double-quote) is encapsulating the current token.
    $Quote = $ScriptString.SubString($Token.Start,1)
    If(($Quote -ne "'") -AND ($Quote -ne '"')) {Write-Error "Parsed an invalid string encapsulator ($Quote) from the following token: $($Token.Content)`nA single- or double-quote was expected."; Exit;}

    # If a variable is present in a string, more work needs to be done to extract from string. Warning maybe should be thrown either way.
    # Must come back and address this after vacation.
    # Variable can be displaying or setting: "setting var like $($var='secret') and now displaying $var"
    # For now just split on whitespace instead of passing to Out-Concatenated
    If($Token.Content.Contains('$'))
    {
        $ObfuscatedToken = $Quote + ($Token.Content.Split(' ') -Join " $Quote+$Quote") + $Quote
    
        # Remove extra whitespace added at beginning of $ObfuscatedToken and trailing +" at the end
        $ObfuscatedToken = $Quote + $ObfuscatedToken.SubString(1,$ObfuscatedToken.Length-1)
    }
    Else
    {
        # Concatenate string.   
        $ObfuscatedToken = Out-ConcatenatedString $TokenContent $Quote
    }

    # Encapsulate concatenated string with parentheses to avoid garbled string in scenarios like Write-* methods.
    If($ObfuscatedToken.Length -ne ($Token.Content.Length + 2))
    {
        $ObfuscatedToken = '(' + $ObfuscatedToken + ')'
    }

    # Add the obfuscated token back to $ScriptString.
    # If string is preceded by a . or :: and followed by ( then it is a Member token encapsulated by quotes and now treated as a string.
    # We must add a .Invoke to the concatenated Member string to avoid syntax errors.
    If((($Token.Start -gt 0) -AND ($ScriptString.SubString($Token.Start-1,1) -eq '.')) -OR (($Token.Start -gt 1) -AND ($ScriptString.SubString($Token.Start-2,2) -eq '::')) -AND ($ScriptString.SubString($Token.Start+$Token.Length,1) -eq '('))
    {
        $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + '.Invoke' + $ScriptString.SubString($Token.Start+$Token.Length)
    }
    Else
    {
        $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
    }
    
    Return $ScriptString
}


Function Out-ObfuscatedCommandTokenLevel2
{
<#
.SYNOPSIS

Obfuscates command token by converting it to a concatenated string and using splatting to invoke the command.

Invoke-Obfuscation Function: Out-ObfuscatedCommandTokenLevel2
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedCommandTokenLevel2 obfuscates a given command token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'Command'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-ObfuscatedCommandTokenLevel2 $ScriptString $Token}
C:\PS> $ScriptString

&(  'WriTe'+'-HOs'+'T') 'Hello World!' -ForegroundColor Green; . ("Wri"+"te-HOs"+"t" ) 'Obfuscation Rocks!' -ForegroundColor Green

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'Command' 2
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )

    # If ticks are already present in current Token then remove so they will not interfere with string concatenation.
    $TokenContent = $Token.Content
    If($TokenContent.Contains('`')) {$TokenContent = $TokenContent.Replace('`','')}

    # Convert $Token to character array for easier manipulation.
    $TokenArray = [Char[]]$TokenContent
    
    # Randomly upper- and lower-case characters in current token.
    $TokenArray = Out-RandomCase $TokenArray

    # Randomly choose between a single quote and double quote.
    $RandomQuote = Get-Random -InputObject @("'","`"")

    # Concatenate string.
    $ObfuscatedToken = Out-ConcatenatedString ($TokenArray -Join '') $RandomQuote
    
    # Encapsulate $ObfuscatedToken with parentheses.
    $ObfuscatedToken = '(' + $ObfuscatedToken + ')'
    
    # Randomly choose between the & and . Invoke Operators.
    # In certain large scripts where more than one parameter are being passed into a custom function 
    # (like Add-SignedIntAsUnsigned in Invoke-Mimikatz.ps1) then using . will cause errors but & will not.
    # For now we will default to only & if $ScriptString.Length -gt 10000
    If($ScriptString.Length -gt 10000) {$RandomInvokeOperator = '&'}
    Else {$RandomInvokeOperator = Get-Random -InputObject @('&','.')}
    
    # Add invoke operator (and potentially whitespace) to complete splatting command.
    $ObfuscatedToken = $RandomInvokeOperator + $ObfuscatedToken
    
    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
    
    Return $ScriptString
}


Function Out-ObfuscatedWithTicks
{
<#
.SYNOPSIS

HELPER FUNCTION :: Obfuscates any token by randomizing its case and randomly adding ticks. It takes PowerShell special characters into account so you will get `N instead of `n, `T instead of `t, etc.

Invoke-Obfuscation Function: Out-ObfuscatedWithTicks
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedWithTicks obfuscates given input as a helper function to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'Command'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token}
C:\PS> $ScriptString

WrI`Te-Ho`sT 'Hello World!' -ForegroundColor Green; WrIte-`hO`S`T 'Obfuscation Rocks!' -ForegroundColor Green

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'Command' 2
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )

    # If ticks are already present in current Token then Return $ScriptString as is.
    If($Token.Content.Contains('`'))
    {
        Return $ScriptString
    }
    
    # The Parameter Attributes in $MemberTokensToOnlyRandomCase (defined at beginning of script) cannot be obfuscated like other Member Tokens
    # For these tokens we will only randomize the case and then return as is.
    # Source: https://social.technet.microsoft.com/wiki/contents/articles/15994.powershell-advanced-function-parameter-attributes.aspx
    If($MemberTokensToOnlyRandomCase -Contains $Token.Content.ToLower())
    {
        $ObfuscatedToken = Out-RandomCase $Token.Content
        $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
        Return $ScriptString
    }
    
    # Convert $Token to character array for easier manipulation.
    $TokenArray = [Char[]]$Token.Content

    # Randomly upper- and lower-case characters in current token.
    $TokenArray = Out-RandomCase $TokenArray

    # Choose a random percentage of characters to obfuscate with ticks in current token.
    $ObfuscationPercent = Get-Random -Minimum 15 -Maximum 30
    
    # Convert $ObfuscationPercent to the exact number of characters to obfuscate in the current token.
    $NumberOfCharsToObfuscate = [int]($Token.Length*($ObfuscationPercent/100))

    # Guarantee that at least one character will be obfuscated.
    If($NumberOfCharsToObfuscate -eq 0) {$NumberOfCharsToObfuscate = 1}

    # Select random character indexes to obfuscate with ticks (excluding first and last character in current token).
    $CharIndexesToObfuscate = (Get-Random -InputObject (1..($TokenArray.Length-2)) -Count $NumberOfCharsToObfuscate)
    
    # Special characters in PowerShell must be upper-cased before adding a tick before the character.
    $SpecialCharacters = @('a','b','f','n','r','t','v')
 
    # Remove the possibility of a single tick being placed only before the token string.
    # This would leave the string value completely intact, thus defeating the purpose of the tick obfuscation.
    $ObfuscatedToken = '' #$NULL
    $ObfuscatedToken += $TokenArray[0]
    For($i=1; $i -le $TokenArray.Length-1; $i++)
    {
        $CurrentChar = $TokenArray[$i]
        If($CharIndexesToObfuscate -Contains $i)
        {
            # Set current character to upper case in case it is in $SpecialCharacters (i.e., `N instead of `n so it's not treated as a newline special character)
            If($SpecialCharacters -Contains $CurrentChar) {$CurrentChar = ([string]$CurrentChar).ToUpper()}
            
            # Skip adding a tick if character is a special character where case does not apply.
            If($CurrentChar -eq '0') {$ObfuscatedToken += $CurrentChar; Continue}
            
            # Add tick.
            $ObfuscatedToken += '`' + $CurrentChar
        }
        Else
        {
            $ObfuscatedToken += $CurrentChar
        }
    }
    
    # If $Token immediately follows a . or :: (and does not begin $ScriptString) then encapsulate with double quotes so ticks are valid.
    # E.g. both InvokeCommand and InvokeScript in $ExecutionContext.InvokeCommand.InvokeScript
    If((($Token.Start -gt 0) -AND ($ScriptString.SubString($Token.Start-1,1) -eq '.')) -OR (($Token.Start -gt 1) -AND ($ScriptString.SubString($Token.Start-2,2) -eq '::')))
    {
        # Add the obfuscated token back to $ScriptString after encapsulating it with double quotes since ticks were introduced.
        $ScriptString = $ScriptString.SubString(0,$Token.Start) + '"' + $ObfuscatedToken + '"' + $ScriptString.SubString($Token.Start+$Token.Length)
    }
    Else
    {
        # Add the obfuscated token back to $ScriptString.
        $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
    }

    Return $ScriptString
}


Function Out-ObfuscatedMemberTokenLevel3
{
<#
.SYNOPSIS

Obfuscates member token by randomizing its case, randomly concatenating the member as a string and adding the .invoke operator. This enables us to treat a member token as a string to gain the obfuscation benefits of a string.

Invoke-Obfuscation Function: Out-ObfuscatedMemberTokenLevel3
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedMemberTokenLevel3 obfuscates a given token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Tokens

Specifies the token array containing the token we will obfuscate.

.PARAMETER Index

Specifies the index of the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "[console]::WriteLine('Hello World!'); [console]::WriteLine('Obfuscation Rocks!')"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null)
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {If($Tokens[$i].Type -eq 'Member') {$ScriptString = Out-ObfuscatedMemberTokenLevel3 $ScriptString $Tokens $i}}
C:\PS> $ScriptString

[console]::('Wr'+'I'+'teL'+'Ine').Invoke('Hello World!'); [console]::("wrI"+"tel"+"INE").Invoke('Obfuscation Rocks!')

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {[console]::WriteLine('Hello World!'); [console]::WriteLine('Obfuscation Rocks!')} 'Member' 3
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken[]]
        $Tokens,
        
        [Parameter(Position = 2, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Int]
        $Index
    )

    $Token = $Tokens[$Index]

    # The Parameter Attributes in $MemberTokensToOnlyRandomCase (defined at beginning of script) cannot be obfuscated like other Member Tokens
    # For these tokens we will only randomize the case and then return as is.
    # Source: https://social.technet.microsoft.com/wiki/contents/articles/15994.powershell-advanced-function-parameter-attributes.aspx
    If($MemberTokensToOnlyRandomCase -Contains $Token.Content.ToLower())
    {
        $ObfuscatedToken = Out-RandomCase $Token.Content
        $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
        Return $ScriptString
    }

    # If $Token immediately follows a . or :: (and does not begin $ScriptString) of if followed by [] type cast within 
    #   parentheses then only allow Member token to be obfuscated with ticks and quotes.
    # The exception to this is when the $Token is immediately followed by an opening parenthese, like in .DownloadString(
    # E.g. both InvokeCommand and InvokeScript in $ExecutionContext.InvokeCommand.InvokeScript
    # E.g. If $Token is 'Invoke' then concatenating it and then adding .Invoke() would be redundant.

    $RemainingSubString = 50
    If($RemainingSubString -gt $ScriptString.SubString($Token.Start+$Token.Length).Length)
    {
        $RemainingSubString = $ScriptString.SubString($Token.Start+$Token.Length).Length
    }
    If(((($Token.Start -gt 0) -AND ($ScriptString.SubString($Token.Start-1,1) -eq '.')) -OR (($Token.Start -gt 1) -AND ($ScriptString.SubString($Token.Start-2,2) -eq '::'))) -AND (($ScriptString.Length -ge $Token.Start+$Token.Length+1) -AND (($ScriptString.SubString($Token.Start+$Token.Length,1) -ne '(') -OR ($ScriptString.SubString($Token.Start+$Token.Length,$RemainingSubString).Contains('[')))))
    {
        # We will use the scriptString length prior to obfuscating 'invoke' to help extract the this token after obfuscation so we can add quotes before re-inserting it. 
        $PrevLength = $ScriptString.Length
        
        # Obfuscate 'invoke' token with ticks.
        $ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token
        
        #$TokenLength = 'invoke'.Length + ($ScriptString.Length - $PrevLength)
        $TokenLength = $Token.Length + ($ScriptString.Length - $PrevLength)
        
        # Encapsulate obfuscated and extracted token with double quotes if it is not already.
        $ObfuscatedTokenExtracted =  $ScriptString.SubString($Token.Start,$TokenLength)
        If($ObfuscatedTokenExtracted.StartsWith('"') -AND $ObfuscatedTokenExtracted.EndsWith('"'))
        {
            $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedTokenExtracted + $ScriptString.SubString($Token.Start+$TokenLength)
        }
        Else
        {
            $ScriptString = $ScriptString.SubString(0,$Token.Start) + '"' + $ObfuscatedTokenExtracted + '"' + $ScriptString.SubString($Token.Start+$TokenLength)
        }

        Return $ScriptString
    }

    # If ticks are already present in current Token then remove so they will not interfere with string concatenation.
    If($Token.Content.Contains('`')) {$Token.Content = $Token.Content.Replace('`','')}

    # Convert $Token to character array for easier manipulation.
    $TokenArray = [Char[]]$Token.Content

    # Randomly upper- and lower-case characters in current token.
    $TokenArray = Out-RandomCase $TokenArray
    
    # Randomly choose between a single quote and double quote
    $RandomQuote = Get-Random -InputObject @("'","`"")

    # Concatenate string.
    $ObfuscatedToken = Out-ConcatenatedString ($TokenArray -Join '') $RandomQuote
  
    # Encapsulate $ObfuscatedToken with parentheses.
    $ObfuscatedToken = '(' + $ObfuscatedToken + ')'

    # Retain current token before re-tokenizing if 'invoke' member was introduced (see next For loop below)
    $InvokeToken = $Token
    # Retain how much the token has increased during obfuscation process so far.
    $TokenLengthIncrease = $ObfuscatedToken.Length - $Token.Content.Length

    # Add .Invoke if Member token was originally immediately followed by '('
    If(($Index -lt $Tokens.Count) -AND ($Tokens[$Index+1].Content -eq '(') -AND ($Tokens[$Index+1].Type -eq 'GroupStart')) 
    {
        $ObfuscatedToken = $ObfuscatedToken + '.Invoke'
    }
    
    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)  

    Return $ScriptString
}


Function Out-ObfuscatedCommandArgumentTokenLevel3
{
<#
.SYNOPSIS

Obfuscates command argument token by randomly concatenating the command argument as a string and encapsulating it with parentheses.

Invoke-Obfuscation Function: Out-ObfuscatedCommandArgumentTokenLevel3
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedCommandArgumentTokenLevel3 obfuscates a given token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'CommandArgument'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-ObfuscatedCommandArgumentTokenLevel3 $ScriptString $Token}
C:\PS> $ScriptString

Write-Host 'Hello World!' -ForegroundColor ('Gr'+'een'); Write-Host 'Obfuscation Rocks!' -ForegroundColor ("Gree"+"n")

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'CommandArgument' 3
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )

    # Function name declarations are CommandArgument tokens that cannot be obfuscated with concatenations.
    # For these we will obfuscated them with ticks because this changes the string from AMSI's perspective but not the final functionality.
    If($ScriptString.SubString(0,$Token.Start-1).Trim().ToLower().EndsWith('function'))
    {
        $ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token
        Return $ScriptString
    }
    
    # If ticks are already present in current Token then remove so they will not interfere with string concatenation.
    If($Token.Content.Contains('`')) {$Token.Content = $Token.Content.Replace('`','')}

    # Randomly choose between a single quote and double quote
    $RandomQuote = Get-Random -InputObject @("'","`"")

    # Concatenate string.
    $ObfuscatedToken = Out-ConcatenatedString $Token.Content $RandomQuote
    
    # Encapsulate $ObfuscatedToken with parentheses.
    $ObfuscatedToken = '(' + $ObfuscatedToken + ')'
    
    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
    
    Return $ScriptString
}

<#
# Commented out Type token obfuscation since it errors after PS 2.0 (i.e. [In`T][C`har]123 works in PS2.0 but not in later versions)
Function Out-ObfuscatedTypeTokenLevel1
{
<#
.SYNOPSIS

Obfuscates type token by randomly adding ticks.

Invoke-Obfuscation Function: Out-ObfuscatedTypeTokenLevel1
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedTypeTokenLevel1 obfuscates a given token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "[console]::WriteLine('Hello World!'); [console]::WriteLine('Obfuscation Rocks!')"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'Type'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-ObfuscatedTypeTokenLevel1 $ScriptString $Token}
C:\PS> $ScriptString

[Co`NSOL`e]::WriteLine('Hello World!'); [cO`NSoLE]::WriteLine('Obfuscation Rocks!')

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {[console]::WriteLine('Hello World!'); [console]::WriteLine('Obfuscation Rocks!')} 'Type' 1
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>
<#

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )

    # Length of pre-obfuscated ScriptString will be important in extracting out the obfuscated token before we add curly braces.
    $PrevLength = $ScriptString.Length

    $ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token
    
    # Remove ticks if they immediately precede square brackets.
    # E.g. [char`[]] will cause an error.
    If($ScriptString.Contains('`['))
    {
        $ScriptString = $ScriptString.Replace('`[','[')
    }
    If($ScriptString.Contains('`]'))
    {
        $ScriptString = $ScriptString.Replace('`]',']')
    }

    # Pull out ObfuscatedToken from ScriptString and add square brackets around obfuscated type token.
    $OriginalSecondHalfLength = $PrevLength-($Token.Start+$Token.Length)
    $ObfuscatedToken = $ScriptString.SubString($Token.Start,($ScriptString.Length-$OriginalSecondHalfLength)-$Token.Start)
    $ObfuscatedToken = '[' + $ObfuscatedToken + ']'

    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString(($ScriptString.Length-$OriginalSecondHalfLength))

    Return $ScriptString
}#>


Function Out-ObfuscatedVariableTokenLevel1
{
<#
.SYNOPSIS

Obfuscates variable token by randomizing its case, randomly adding ticks and wrapping it in curly braces.

Invoke-Obfuscation Function: Out-ObfuscatedVariableTokenLevel1
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ObfuscatedVariableTokenLevel1 obfuscates a given token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "`$Message1 = 'Hello World!'; Write-Host `$Message1 -ForegroundColor Green; `$Message2 = 'Obfuscation Rocks!'; Write-Host `$Message2 -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'Variable'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-ObfuscatedVariableTokenLevel1 $ScriptString $Token}
C:\PS> $ScriptString

${m`e`ssAge1} = 'Hello World!'; Write-Host ${MEss`Ag`e1} -ForegroundColor Green; ${meSsAg`e`2} = 'Obfuscation Rocks!'; Write-Host ${M`es`SagE2} -ForegroundColor Green

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {$Message1 = 'Hello World!'; Write-Host $Message1 -ForegroundColor Green; $Message2 = 'Obfuscation Rocks!'; Write-Host $Message2 -ForegroundColor Green} 'Variable' 1
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )

    # Length of pre-obfuscated ScriptString will be important in extracting out the obfuscated token before we add curly braces.
    $PrevLength = $ScriptString.Length

    $ScriptString = Out-ObfuscatedWithTicks $ScriptString $Token   

    # Pull out ObfuscatedToken from ScriptString and add curly braces around obfuscated variable token.
    $ObfuscatedToken = $ScriptString.SubString($Token.Start,$Token.Length+($ScriptString.Length-$PrevLength))
    $ObfuscatedToken = '${' + $ObfuscatedToken + '}'

    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length+($ScriptString.Length-$PrevLength))

    Return $ScriptString
}


Function Out-RandomCaseRandomQuotes
{
<#
.SYNOPSIS

HELPER FUNCTION :: Obfuscates any token by randomizing its case and encapsulating the result with randomly selected single- or double-quotes.

Invoke-Obfuscation Function: Out-RandomCaseRandomQuotes
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-RandomCaseRandomQuotes obfuscates given input as a helper function to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'CommandArgument'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-RandomCaseRandomQuotes $ScriptString $Token}
C:\PS> $ScriptString

Write-Host 'Hello World!' -ForegroundColor "GREeN"; Write-Host 'Obfuscation Rocks!' -ForegroundColor "gReeN"

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'CommandArgument' 1
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )
                
    # Convert $Token to character array for easier manipulation.
    $TokenArray = [Char[]]$Token.Content
    
    # Randomly upper- and lower-case characters in current token.
    $TokenArray = Out-RandomCase $TokenArray
    
    # Convert character array back to string.
    $ObfuscatedToken = $TokenArray -Join ''
    
    # Randomly choose between a single quote and double quote
    $RandomQuote = Get-Random -InputObject @("'","`"")
    $ObfuscatedToken = $RandomQuote + $ObfuscatedToken + $RandomQuote

    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
    
    Return $ScriptString
}


Function Out-ConcatenatedString
{
<#
.SYNOPSIS

HELPER FUNCTION :: Obfuscates any string by randomly concatenating it and encapsulating the result with input single- or double-quotes.

Invoke-Obfuscation Function: Out-ConcatenatedString
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-ConcatenatedString obfuscates given input as a helper function to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER InputVal

Specifies the string to obfuscate.

.PARAMETER Quote

Specifies the single- or double-quote used to encapsulate the concatenated string.

.EXAMPLE

C:\PS> Out-ConcatenatedString "String to be concatenated" '"'

"String "+"to be "+"co"+"n"+"c"+"aten"+"at"+"ed

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'CommandArgument' 3
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $InputVal,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Char]
        $Quote
    )

    # Strip leading and trailing single- or double-quotes if there are no more quotes of the same kind in $InputVal.
    # E.g. 'stringtoconcat' will have the leading and trailing quotes removed and will use $Quote.
    # But a string "'G'+'" passed to this function as 'G'+' will have all quotes remain as part of the $InputVal string.
    If($InputVal.Contains("'")) {$InputVal = $InputVal.Replace("'","`'")}
    If($InputVal.Contains('"')) {$InputVal = $InputVal.Replace('"','`"')}
    
    # Do nothing if string is of length 2 or less
    If($InputVal.Length -le 2)
    {
        $ObfuscatedToken = $Quote + $InputVal + $Quote
        Return $ObfuscatedToken
    }

    # Choose a random percentage of characters to have concatenated in current token.
    # If the current token is greater than 1000 characters (as in SecureString or Base64 strings) then set $ConcatPercent much lower
    If($InputVal.Length -gt 25000)
    {
        $ConcatPercent = Get-Random -Minimum 0.05 -Maximum 0.10
    }
    ElseIf($InputVal.Length -gt 1000)
    {
        $ConcatPercent = Get-Random -Minimum 2 -Maximum 4
    }
    Else
    {
        $ConcatPercent = Get-Random -Minimum 15 -Maximum 30
    }
    
    # Convert $ConcatPercent to the exact number of characters to concatenate in the current token.
    $ConcatCount =  [Int]($InputVal.Length*($ConcatPercent/100))

    # Guarantee that at least one concatenation will occur.
    If($ConcatCount -eq 0) 
    {
        $ConcatCount = 1
    }

    # Select random indexes on which to concatenate.
    $CharIndexesToConcat = (Get-Random -InputObject (1..($InputVal.Length-1)) -Count $ConcatCount) | Sort-Object
  
    # Perform inline concatenation.
    $LastIndex = 0

    ForEach($IndexToObfuscate in $CharIndexesToConcat)
    {
        # Extract substring to concatenate with $ObfuscatedToken.
        $SubString = $InputVal.SubString($LastIndex,$IndexToObfuscate-$LastIndex)
       
        # Concatenate with quotes and addition operator.
        $ObfuscatedToken += $SubString + $Quote + "+" + $Quote

        $LastIndex = $IndexToObfuscate
    }

    # Add final substring.
    $ObfuscatedToken += $InputVal.SubString($LastIndex)
    $ObfuscatedToken += $FinalSubString

    # Add final quotes if necessary.
    If(!($ObfuscatedToken.StartsWith($Quote) -AND $ObfuscatedToken.EndsWith($Quote)))
    {
        $ObfuscatedToken = $Quote + $ObfuscatedToken + $Quote
    }
   
    # Remove any existing leading or trailing empty string concatenation.
    If($ObfuscatedToken.StartsWith("''+"))
    {
        $ObfuscatedToken = $ObfuscatedToken.SubString(3)
    }
    If($ObfuscatedToken.EndsWith("+''"))
    {
        $ObfuscatedToken = $ObfuscatedToken.SubString(0,$ObfuscatedToken.Length-3)
    }
    
    Return $ObfuscatedToken
}


Function Out-RandomCase
{
<#
.SYNOPSIS

HELPER FUNCTION :: Obfuscates any string or char[] by randomizing its case.

Invoke-Obfuscation Function: Out-RandomCase
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-RandomCase obfuscates given input as a helper function to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER InputValStr

Specifies the string to obfuscate.

.PARAMETER InputVal

Specifies the char[] to obfuscate.

.EXAMPLE

C:\PS> Out-RandomCase "String to have case randomized"

STrINg to haVe caSe RAnDoMIzeD

C:\PS> Out-RandomCase ([char[]]"String to have case randomized")

StrING TO HavE CASE randOmIzeD

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host 'Hello World!' -ForegroundColor Green; Write-Host 'Obfuscation Rocks!' -ForegroundColor Green} 'Command' 3
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding( DefaultParameterSetName = 'InputVal')] Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ParameterSetName = 'InputValStr')]
        [ValidateNotNullOrEmpty()]
        [String]
        $InputValStr,

        [Parameter(Position = 0, ParameterSetName = 'InputVal')]
        [ValidateNotNullOrEmpty()]
        [Char[]]
        $InputVal
    )
    
    If($PSBoundParameters['InputValStr'])
    {
        # Convert string to char array for easier manipulation.
        $InputVal = [Char[]]$InputValStr
    }

    # Randomly convert each character to upper- or lower-case.
    $OutputVal = ($InputVal | ForEach-Object {If((Get-Random -Minimum 0 -Maximum 2) -eq 0) {([String]$_).ToUpper()} Else {([String]$_).ToLower()}}) -Join ''

    Return $OutputVal
}


Function Out-RandomWhitespace
{
<#
.SYNOPSIS

Obfuscates operator/groupstart/groupend/statementseparator token by adding random amounts of whitespace before/after the token depending on the token value and its immediate surroundings in the input script.

Invoke-Obfuscation Function: Out-RandomWhitespace
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-RandomWhitespace adds random whitespace before/after a given token and places it back into the provided PowerShell script to evade detection by simple IOCs and process execution monitoring relying solely on command-line arguments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Tokens

Specifies the token array containing the token we will obfuscate.

.PARAMETER Index

Specifies the index of the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "Write-Host ('Hel'+'lo Wo'+'rld!') -ForegroundColor Green; Write-Host ('Obfu'+'scation Ro'+'cks!') -ForegroundColor Green"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null)
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {If(($Tokens[$i].Type -eq 'Operator') -OR ($Tokens[$i].Type -eq 'GroupStart') -OR ($Tokens[$i].Type -eq 'GroupEnd')) {$ScriptString = Out-RandomWhitespace $ScriptString $Tokens $i}}
C:\PS> $ScriptString

Write-Host ('Hel'+  'lo Wo'  + 'rld!') -ForegroundColor Green; Write-Host ( 'Obfu'  +'scation Ro' +  'cks!') -ForegroundColor Green

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {Write-Host ('Hel'+'lo Wo'+'rld!') -ForegroundColor Green; Write-Host ('Obfu'+'scation Ro'+'cks!') -ForegroundColor Green} 'RandomWhitespace' 1
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken[]]
        $Tokens,
        
        [Parameter(Position = 2, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Int]
        $Index
    )
        
    $Token = $Tokens[$Index]

    $ObfuscatedToken = $Token.Content
    
    # Do not add DEFAULT setting in below Switch block.
    Switch($Token.Content) {
        '(' {$ObfuscatedToken = $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        ')' {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken}
        ';' {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        '|' {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        '+' {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        '=' {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        '&' {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        '.' {
            # Retrieve character in script immediately preceding the current token
            If($Index -eq 0) {$PrevChar = ' '}
            Else {$PrevChar = $ScriptString.SubString($Token.Start-1,1)}
            
            # Only add randomized whitespace to . if it is acting as a standalone invoke operator (either at the beginning of the script or immediately preceded by ; or whitespace)
            If(($PrevChar -eq ' ') -OR ($PrevChar -eq ';')) {$ObfuscatedToken = ' '*(Get-Random -Minimum 0 -Maximum 3) + $ObfuscatedToken + ' '*(Get-Random -Minimum 0 -Maximum 3)}
        }
    }
    
    # Add the obfuscated token back to $ScriptString.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ObfuscatedToken + $ScriptString.SubString($Token.Start+$Token.Length)
    
    Return $ScriptString
}


Function Out-RemoveComments
{
<#
.SYNOPSIS

Obfuscates variable token by removing all comment tokens. This is primarily since A/V uses strings in comments as part of many of their signatures for well known PowerShell scripts like Invoke-Mimikatz.

Invoke-Obfuscation Function: Out-RemoveComments
Author: Daniel Bohannon (@danielhbohannon)
License: Apache License, Version 2.0
Required Dependencies: None
Optional Dependencies: None
 
.DESCRIPTION

Out-RemoveComments obfuscates a given token by removing all comment tokens from the provided PowerShell script to evade detection by simple IOCs or A/V signatures based on strings in PowerShell script comments. For the most complete obfuscation all tokens in a given PowerShell script or script block (cast as a string object) should be obfuscated via the corresponding obfuscation functions and desired obfuscation levels in Out-ObfuscatedTokenCommand.ps1.

.PARAMETER ScriptString

Specifies the string containing your payload.

.PARAMETER Token

Specifies the token to obfuscate.

.EXAMPLE

C:\PS> $ScriptString = "`$Message1 = 'Hello World!'; Write-Host `$Message1 -ForegroundColor Green; `$Message2 = 'Obfuscation Rocks!'; Write-Host `$Message2 -ForegroundColor Green #COMMENT"
C:\PS> $Tokens = [System.Management.Automation.PSParser]::Tokenize($ScriptString,[ref]$null) | Where-Object {$_.Type -eq 'Comment'}
C:\PS> For($i=$Tokens.Count-1; $i -ge 0; $i--) {$Token = $Tokens[$i]; $ScriptString = Out-RemoveComments $ScriptString $Token}
C:\PS> $ScriptString

$Message1 = 'Hello World!'; Write-Host $Message1 -ForegroundColor Green; $Message2 = 'Obfuscation Rocks!'; Write-Host $Message2 -ForegroundColor Green

.NOTES

This cmdlet is most easily used by passing a script block or file path to a PowerShell script into the Out-ObfuscatedTokenCommand function with the corresponding token type and obfuscation level since Out-ObfuscatedTokenCommand will handle token parsing, reverse iterating and passing tokens into this current function.
C:\PS> Out-ObfuscatedTokenCommand {$Message1 = 'Hello World!'; Write-Host $Message1 -ForegroundColor Green; $Message2 = 'Obfuscation Rocks!'; Write-Host $Message2 -ForegroundColor Green #COMMENT} 'Comment' 1
This is a personal project developed by Daniel Bohannon while an employee at MANDIANT, A FireEye Company.

.LINK

http://www.danielbohannon.com
#>

    [CmdletBinding()] Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ScriptString,
    
        [Parameter(Position = 1, Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSToken]
        $Token
    )
    
    # Remove current Comment token.
    $ScriptString = $ScriptString.SubString(0,$Token.Start) + $ScriptString.SubString($Token.Start+$Token.Length)
    
    Return $ScriptString
}