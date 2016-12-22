#!/usr/bin/perl

open (INF, "<", $ARGV[0]) or die "couldn't open sourcecode\n";

# these lines of code slurp the whole file into one scalar $in_buffer
{
    local $/;
    $in_buffer = <INF>;
}

# use the following lines in your program if you wish to add a $ to
# the end of the input program
chomp($in_buffer);
$in_buffer .= " \$";

# Some global variables
my @reservedNoSpace = < 'program' 'begin' 'end'>;
my @reservedAllowSpace = < 'read' 'write' 'if' 'then' 'else' 'while' 'do' >;
my @charTerm = < ';' ':=' '(' ',' ')' '+' '-' '/' '=' '<>' '<=' '>=' '\>' '\<' >;
my $star = "\*";
my $token;
my $lineCount = 1;

# MAIN PROGRAM, just call lex and program subroutines
lex();
program();

sub lex()
{
    # Get the next token
    if ($in_buffer =~ /(\S+)/s)
    {
        while($` =~ "\n")
        {
            $lineCount = $lineCount + 1;
        }

        $inputToken = $1;
        $in_buffer = $';
    }

    if($inputToken =~ /^\$$/)
    {
        $token = "";
        return;
    }

    # Check for reserved words that don't allow spaces
    for my $reservedWord (@reservedNoSpace)
    {
        if ($inputToken eq $reservedWord)
        {
            $token = $reservedWord;
            return;
        }
    }

    # Check for reserved words that allow spaces
    for my $reservedWordAllowSpace (@reservedAllowSpace)
    {
        if ($inputToken =~ /^$reservedWordAllowSpace/)
        {
            $in_buffer = $' . $in_buffer;
            $token = $reservedWordAllowSpace;
            return;
        }
    }

    # Check for character terminals
    for my $terminal (@charTerm)
    {
        if ($inputToken =~ /^\Q$terminal\E/)
        {
            $in_buffer = $' . $in_buffer;
            $token = $terminal;
            return;
        }
    }

    # Check for star (was showing the directory, so I had to isolate it)
    if ($inputToken =~ /^\Q$star\E/)
    {
         $in_buffer = $' . $in_buffer;
         $token = $star;
         return;
    }
    
    # Check for program name
    if ($token eq "program" & $inputToken =~ /^[A-Z][a-zA-Z0-9]*$/)
    {
        $token = "PROGNAME";
        return;
    }  
    
    # Check for variable declaration
    if ($inputToken =~ /^[a-zA-Z][a-zA-Z0-9]*/)
    {
        $in_buffer = $' . $in_buffer;
        $token = "VARIABLE";
        return;
    }

    # Check for constants
    if ($inputToken =~ /^[0-9]+/)
    {
        $in_buffer = $' . $in_buffer;
        $token = "CONSTANT";
        return;
    }
    $token = $inputToken;
}

# Return the next token without removing it from the string
sub peek()
{
    # Get the next token
    if ($in_buffer =~ /(\S+)/)
    {
        $inputToken = $1;
    }
    
    # Check for reserved words
    for my $reservedWord (@reserved)
    {
        if ($inputToken eq $reservedWord)
        {
            return $reservedWord;
        }
    }

    # Check for character terminals
    for my $terminal (@charTerm)
    {
        if ($inputToken =~ m/^\Q$terminal\E/)
        {
            return $terminal;
        }
    }
    # Check for star (was showing the directory, so I had to isolate it)
    if ($inputToken =~ /^\Q$star\E/)
    {
         return $star;
    }
    
    # Check for program name
    if ($token eq "program" & $inputToken =~ /^[A-Z][a-zA-Z0-9]*$/)
    {
        return "PROGNAME";
    }  
    
    # Check for variable declaration
    if ($inputToken =~ /^[a-zA-Z][a-zA-Z0-9]*/)
    {
        return "VARIABLE";
    }

    # Check for constants
    if ($inputToken =~ /^[0-9]+/)
    {
        return "CONSTANT";
    }
}

sub program()
{
    # Check first token for 'program'
    if ($token ne "program")
    {
        error("program", $token);
        return;
    }

    lex();

    # Check second token for the program name
    if ($token ne "PROGNAME")
    {
        error("PROGNAME", $token);
        return;
    }

    lex();

    # Check third token for 'begin'
    if ($token ne "begin")
    {
        error("begin", $token);
        return;
    }

    # Enter compound statement
    compoundStatement();
    
    # If anything is left after the main compound statement, throw an error
    if ($in_buffer ne " \$")
    {
        print ("Error: Unrecognized characters $in_buffer");
    }
}

sub compoundStatement()
{
    statement();

    # Keep chaining statements until we see 'end'
    while (1)
    {
        lex();
        
        if ($token eq "end")
        {
            last;
        }

        # Ends current statement
        if ($token ne ";")
        {
            error(";", $token);
            return;
        }

        statement();
    }
}

sub statement()
{
    lex();

    # Check for assignment, read and write statements
    if ($token eq "VARIABLE" or $token eq "read" or $token eq "write")
    {
        simpleStatement();
    } else {
        structuredStatement();
    }
}

sub simpleStatement()
{
    # Redirect into correct method
    if($token eq "VARIABLE")
    {
        assignmentStatement();
    } elsif ($token eq "read") {
        readStatement();
    } elsif ($token eq "write") {
        writeStatement();
    } else {
        error("VARIABLE, read or write", $token);
    }
}

sub assignmentStatement()
{
    lex();

    # Expect assignment operator
    if ($token ne ":=")
    {
        error(":=", $token);
        return;
    }
    expression();
}

sub readStatement()
{
    lex();

    # Expect left parenthesis
    if ($token ne "(")
    {
        error("(", $token);
        return;
    }

    lex();

    # Expect variable
    if ($token ne "VARIABLE")
    {
        error("VARIABLE", $token);
        return;
    }

    # Keep chaining variables until seeing ')'
    while(1)
    {
        lex();
        if ($token eq ")")
        {
            last;
        }

        if ($token ne ",")
        {
            error(",", $token);
            return;

        } else {           
            lex();
            if ($token ne "VARIABLE")
            {
                error("VARIABLE", $token);
                return;
            }
        }
    }
}

sub writeStatement()
{
    lex();
    expression();

    # Keep chaining expressions until seeing ')'
    while(1)
    {
        lex();
        if($token eq ")")
        {
            last;
        }

        if($token ne ",")
        {
            error(",", $token);
        } else {
            expression();
        }
    }
}

sub structuredStatement()
{
    # Redirect into correct method
    if ($token eq "if")
    {
        ifStatement();
    } elsif ($token eq "while")
    {
        whileStatement();
    } elsif ($token eq "begin") {
        compoundStatement();
    } else {
        error("if, while or begin", $token);
        return;
    }
}

sub ifStatement()
{
    expression();
    lex();

    if($token ne "then")
    {
        error("then", $token);
        return;
    }
    statement();

    # Check for 'else' without taking it out of the in_buffer
    if(peek() eq "else")
    {
        lex();
        statement();
    }
}

sub whileStatement()
{
    expression();
    lex();

    # Expect 'do'
    if($token ne "do")
    {
        error("do", $token);
        return;
    }
    statement();
}

sub expression()
{
    simpleExpression();

    my $nextValExpr = peek();
    my @relOperators = relationalOperator();

    # See if there's a relational operator without removing from in_buffer
    for my $op (@relOperators)
    {
        if ($nextValExpr eq $op)
        {
            lex();
            simpleExpression();
            last;
        }
    }
}

sub simpleExpression()
{
    my $nextValsExpr = peek();
    my @signs = sign();

    # See if there's a sign without removing from in_buffer
    for my $op (@signs) 
    {
        if ($nextValsExpr eq $op)
        {
            lex();
            last;
        }
    }

    term();

    # Keep chaining terms and addition operators until there's none left
    while(1)
    {
        my $nextValsExpr = peek();
        my @addOps = additionOperator();
        my $exit = 0;

        for my $op (@addOps) 
        {
            if ($nextValsExpr eq $op)
            {
                lex();
                term();
                last;
            }
            if ($op eq @addOps[-1])
            {
                $exit = 1;
            }
        }
        last if $exit;
    }
}

sub term()
{
    factor();

    # Keep chaining factors and multiplication operators until there's none left
    while(1)
    {
        my $nextValsExpr = peek();
        my @multOps = muliplicationOperator();
        my $exit = 0;

        for my $op (@multOps)
        {
            if ($nextValsExpr eq $op)
            {
                lex();
                factor();
                last;
            }

            if ($op eq @multOps[-1])
            {
                $exit = 1;
            }
        }
        last if $exit;
    }
}

sub factor()
{
    $nextValFactor = peek();

    # Figure out if it's a variable or constant
    if ($nextValFactor eq "VARIABLE")
    {
        lex();
    } elsif ($nextValFactor eq "CONSTANT") {
        lex();
    } else {
        lex();
        
        if ($token ne "(")
        {
            error("(", $token);
        }

        expression();
        lex();

        if ($token ne ")")
        {
            error(")", $token);
        }
    }
}

# Return all sign operators
sub sign()
{
    return ('+', '-');
}

# Return all addition operators
sub additionOperator()
{
    return ('+', '-');
}

# Return all muliplication operators
sub muliplicationOperator()
{
    return ($star, '/');
}

# Return all relational operators
sub relationalOperator()
{
    return ('<>', '<=', '>=', '>', '<');
}

# Print breakpoint message
sub error()
{
    print "Error: Expected \>@_[0]\< but saw \>@_[1]\< on line $lineCount \n";
}