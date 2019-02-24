#!/usr/bin/perl -w
#
# Debugging
#
# database input and output is paired into the two arrays noted
#
my $debug=0; # default - will be overriden by a form parameter or cookie
my @sqlinput=();
my @sqloutput=();

#
# The combination of -w and use strict enforces various 
# rules that make the script more resilient and easier to run
# as a CGI script.
#
use strict;

# The CGI web generation stuff
# This helps make it easy to generate active HTML content
# from Perl
#
# We'll use the "standard" procedural interface to CGI
# instead of the OO default interface
use CGI qw(:standard);


# The interface to the database.  The interface is essentially
# the same no matter what the backend database is.  
#
# DBI is the standard database interface for Perl. Other
# examples of such programatic interfaces are ODBC (C/C++) and JDBC (Java).
#
#
# This will also load DBD::Oracle which is the driver for
# Oracle.
use DBI;

#
#
# A module that makes it easy to parse relatively freeform
# date strings into the unix epoch time (seconds since 1970)
#
use Time::ParseDate;



#
# You need to override these for access to your database
#
my $dbuser="jsb956";
my $dbpasswd="zfIu05jYi";

#
# We don't need to use the Google Maps API for this
#
# my $googlemapskey="AIzaSyB9klUFTyF1cpZrV2297admNPqVTPHAOJw";

#
# The session cookie will contain the user's name and password so that 
# he doesn't have to type it again and again. 
#
# "RWBSession"=>"user/password"
#
# BOTH ARE UNENCRYPTED AND THE SCRIPT IS ALLOWED TO BE RUN OVER HTTP
# THIS IS FOR ILLUSTRATION PURPOSES.  IN REALITY YOU WOULD ENCRYPT THE COOKIE
# AND CONSIDER SUPPORTING ONLY HTTPS
#
my $cookiename="RWBSession";
#
# And another cookie to preserve the debug state
#
my $debugcookiename="RWBDebug";

#
# Get the session input and debug cookies, if any
#
my $inputcookiecontent = cookie($cookiename);
my $inputdebugcookiecontent = cookie($debugcookiename);

#
# Will be filled in as we process the cookies and paramters
#
my $outputcookiecontent = undef;
my $outputdebugcookiecontent = undef;
my $deletecookie=0;
my $user = undef;
my $password = undef;
my $logincomplain=0;
my $signupcomplain=0;
#
# Get the user action and whether he just wants the form or wants us to
# run the form
#
my $action;
my $run;


if (defined(param("act"))) { 
  $action=param("act");
  if (defined(param("run"))) { 
    $run = param("run") == 1;
  } else {
    $run = 0;
  }
} else {
  $action="base";
  $run = 1;
}

my $dstr;

if (defined(param("debug"))) { 
  # parameter has priority over cookie
  if (param("debug") == 0) { 
    $debug = 0;
  } else {
    $debug = 1;
  }
} else {
  if (defined($inputdebugcookiecontent)) { 
    $debug = $inputdebugcookiecontent;
  } else {
    # debug default from script
  }
}

$outputdebugcookiecontent=$debug;

#
#
# Who is this?  Use the cookie or anonymous credentials
#
#
if (defined($inputcookiecontent)) { 
  # Has cookie, let's decode it
  ($user,$password) = split(/\//,$inputcookiecontent);
  $outputcookiecontent = $inputcookiecontent;
} else {
  # No cookie, treat as anonymous user
  ($user,$password) = ("anon","anonanon");
}

#
# Is this a login request or attempt?
# Ignore cookies in this case.
#
if ($action eq "login") { 
  if ($run) { 
    #
    # Login attempt
    #
    # Ignore any input cookie.  Just validate user and
    # generate the right output cookie, if any.
    #
    ($user,$password) = (param('user'),param('password'));
    if (ValidUser($user,$password)) { 
      # if the user's info is OK, then give him a cookie
      # that contains his username and password 
      # the cookie will expire in one hour, forcing him to log in again
      # after one hour of inactivity.
      # Also, land him in the base query screen
      $outputcookiecontent=join("/",$user,$password);
      $action = "base";
      $run = 1;
    } else {
      # uh oh.  Bogus login attempt.  Make him try again.
      # don't give him a cookie
      $logincomplain=1;
      $action="login";
      $run = 0;
    }
  } else {
    #
    # Just a login screen request, but we should toss out any cookie
    # we were given
    #
    undef $inputcookiecontent;
    ($user,$password)=("anon","anonanon");
  }
} 

# If we are being asked to log out, then if 
# we have a cookie, we should delete it.
#
if ($action eq "logout") {
  $deletecookie=1;
  $action = "base";
  $user = "anon";
  $password = "anonanon";
  $run = 1;
}


my @outputcookies;

#
# OK, so now we have user/password
# and we *may* have an output cookie.   If we have a cookie, we'll send it right 
# back to the user.
#
# We force the expiration date on the generated page to be immediate so
# that the browsers won't cache it.
#
if (defined($outputcookiecontent)) { 
  my $cookie=cookie(-name=>$cookiename,
		    -value=>$outputcookiecontent,
		    -expires=>($deletecookie ? '-1h' : '+1h'));
  push @outputcookies, $cookie;
} 


#
# We also send back a debug cookie
#
#
if (defined($outputdebugcookiecontent)) { 
  my $cookie=cookie(-name=>$debugcookiename,
		    -value=>$outputdebugcookiecontent);
  push @outputcookies, $cookie;
}

#
# Headers and cookies sent back to client
#
# The page immediately expires so that it will be refetched if the
# client ever needs to update it
#
print header(-expires=>'now', -cookie=>\@outputcookies);

#
# Now we finally begin generating back HTML
#
#
#print start_html('Red, White, and Blue');
print "<html style=\"height: 100\%\">";
print "<head>";
print "<title>Red, White, and Blue</title>";
print "</head>";

print "<body style=\"height:100\%;margin:0\">";

#
# Force device width, for mobile phones, etc
#
#print "<meta name=\"viewport\" content=\"width=device-width\" />\n";

# This tells the web browser to render the page in the style
# defined in the css file
#
print "<style type=\"text/css\">\n\@import \"rwb.css\";\n</style>\n";

print "<center>" if !$debug;


#
#
# The remainder here is essentially a giant switch statement based
# on $action. 
#
#
#


# LOGIN
#
# Login is a special case since we handled running the filled out form up above
# in the cookie-handling code.  So, here we only show the form if needed
# 
#
if ($action eq "login") { 
  if ($logincomplain) { 
    print "Login failed.  Try again.<p>"
  } 
  if ($logincomplain or !$run) { 
    print start_form(-name=>'Login'),
      h2('Login to your portfolio account'),
	"Name:",textfield(-name=>'user'),	p,
	  "Password:",password_field(-name=>'password'),p,
	    hidden(-name=>'act',default=>['login']),
	      hidden(-name=>'run',default=>['1']),
		submit,
		  end_form;
    print "<h2>Don't have an account? Register for one <a href=\"portf.pl?act=sign-up\"> here </a>";
  }
}

if ($action eq "sign-up") {
  if ($signupcomplain) {
   print "Signup failed. Try entering a unique username and password.";
  }
  if ($run) {
    my $new_password = param('password');
    my $email = param('email');
    my $new_user = param('user');
    if (defined($new_password) && defined($new_user)) {
      my $error = AddUser($new_user, $new_password);
      if ($error) {
	print "Can't sign up because $error";
        $signupcomplain = 1;
        $action = "sign-up";
        $run = 0;
      } else {
        print "You've signed up! Login in <a href=\"portf.pl?act=login\"> here </a>";
        #print "<p> If you provided a valid email address we will send you your username and password</p>";
	if (defined($email)) {
	  #SendEmail($email, $new_user, $new_password);
	}
      }
    } else {
      $signupcomplain = 1;
      $action = "sign-up";
      $run = 0;
      print "The sign up credentials you entered are not valid.";
    }
  } else {
    print start_form(-name=>'sign-up'),
      h2('Register for a portfolio'),
      "Username:",textfield(-name=>'user'),p,
      "Email (Optional. Your username and password will be sent to this address if registration is valid):",textfield(-name=>'email'),p,
      "Password:",password_field(-name=>'password'),p,
      hidden(-name=>'act',default=>['sign-up']),
      hidden(-name=>'run',default=>['1']),
      submit,
      end_form;
  } 
}
#
# BASE
#
# The base action presents the overall page to the browser
# This is the "document" that the JavaScript manipulates
#
#
if ($action eq "base") {
  #
  # The Javascript portion of our app
  #
  print "<script type=\"text/javascript\" src=\"portf.js\"> </script>";

  #
  # And a div to populate with debug info about nearby stuff
  #
  #
  if ($debug) {
    # visible if we are debugging
    print "<div id=\"data\" style=\:width:100\%; height:10\%\"></div>";
  } else {
    # invisible otherwise
    print "<div id=\"data\" style=\"display: none;\"></div>";
  }


# height=1024 width=1024 id=\"info\" name=\"info\" onload=\"UpdateMap()\"></iframe>";
  

  #
  # User mods
  #
  #
  if ($user eq "anon") {
    print "<p>You are not logged in, but you can <a href=\"portf.pl?act=login\">login</a></p>";
  } else {
    print "<p>You are logged in as $user</p>";
    print "<p><a href=\"portf.pl?act=logout&run=1\">Logout</a></p>";
    
    print "<div id=\"cycles\">";

    my ($portfolios, $error) = Portfolios($user);
    if (!$error) {
      my @portfolios = split(/\t/,$portfolios);
      foreach my $portfolio (@portfolios) {
	print "<a href=\"portf.pl?act=portfolio&key=$portfolio\"><p>$portfolio</p></a>";
      }
      print "<a href=\"portf.pl?act=add-port\"><p>+ Add a new portfolio</p></a>";
    }

    print "</div>"; 
  }

}

#
#
# NEAR
#
#
# Nearby committees, candidates, individuals, and opinions
#
#
# Note that the individual data should integrate the FEC data and the more
# precise crowd-sourced location data.   The opinion data is completely crowd-sourced
#
# This form intentionally avoids decoration since the expectation is that
# the client-side javascript will invoke it to get raw data for overlaying on the map
#
#
if ($action eq "near") {
  my $latne = param("latne");
  my $longne = param("longne");
  my $latsw = param("latsw");
  my $longsw = param("longsw");
  my $whatparam = param("what");
  my $format = param("format");
  my $cycle = param("cycle");
  my %what;
  
  $format = "table" if !defined($format);
  $cycle = "1112" if !defined($cycle);

  if (!defined($whatparam) || $whatparam eq "all") { 
    %what = ( committees => 1, 
	      candidates => 1,
	      individuals =>1,
	      opinions => 1);
  } else {
    map {$what{$_}=1} split(/\s*,\s*/,$whatparam);
  }
	       

  if ($what{committees}) { 
    my ($str,$error) = Committees($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby committees</h2>$str";
      } else {
	print $str;
      }
    }
    my ($commToComm, $error) = CommToComm($latne,$longne,$latsw,$longsw,$cycle);
    if (!$error) {
      print $commToComm;
    }
    my ($commToCand, $error) = CommToCand($latne,$longne,$latsw,$longsw,$cycle);
    if (!$error) {
      print $commToCand;
    }
  }
  if ($what{candidates}) {
    my ($str,$error) = Candidates($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby candidates</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{individuals}) {
    my ($str,$error) = Individuals($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby individuals</h2>$str";
      } else {
	print $str;
      }
    }
  }
  if ($what{opinions}) {
    my ($str,$error) = Opinions($latne,$longne,$latsw,$longsw,$cycle,$format);
    if (!$error) {
      if ($format eq "table") { 
	print "<h2>Nearby opinions</h2>$str";
      } else {
	print $str;
      }
	my $OpinionColor;
	my @results = AvgStddevColor($latne,$longne,$latsw,$longsw);
	
	my $avg = $results[0];
	$avg = @{$avg}[0];
	my $stddev = $results[0];
	$stddev = @{$stddev}[1];

	if ($avg > 0){ 
	  $OpinionColor = "BLUE";
	} elsif ($avg < 0){
	  $OpinionColor = "RED";
	} else {
	  $OpinionColor = "WHITE";
	}
	print "<h3>Aggregate Opinion Statistics</h3>";
	print "<div id=\"opinion-ag-stats\" style=\"color: #37e0b3;background-color: $OpinionColor;\">Opinion Aggregate Data: <p> Average: $avg </p> <p> Standard Deviation: $stddev </p> </div>";
    }
  }
}

if ($action eq "add-port") {
  if (!$run) {
    print start_form(-name=>'add-port'),
      h2('Register for a portfolio'),
      "Portfolio name:",textfield(-name=>'name'),p,
      hidden(-name=>'act',default=>['add-port']),
      hidden(-name=>'run',default=>['1']),
      submit,
      end_form;
  } else {
    my $port_name = param('name');
    if (defined($port_name) && $port_name ne "") {
      my $error = AddPortfolio($user, $port_name, 0);
      if ($error) {
	print "there was an error adding the portfolio with that name";
		
      } else {
	print "the portfolio has been added. Return to the <a href=\"portf.pl?act=base\"> home page </a>";
      }
    } else {
      print "You must enter something for your portfolio name";
    }
  }      
}

if ($action eq "portfolio") {
  my $portfolio = param('key');
  if (defined($portfolio)) {
    if (ValidPort($portfolio, $user)) {
      print "<h1> Portfolio: $portfolio</h1><p>Cash Account: 0 (this is static rn)</p><br/><br/>";
      print "<h2> Stock Holdings </h2>";
      print "<p> Once the stock holdings stuff is implemented this is where users can see their holdings </p>";
    } else {
      print "$portfolio is not a valid portfolio. Make sure you are signed in.";
    }
  } else {
    print "No portfolio was selected. Make sure you are signed in and click on a portfolio through the home page";
  }
}

=pod
if ($action eq "invite-user") {
  if (!UserCan($user,"invite-users")) {
    print h2('You do not have the required permissions to invite users.');
  } else {
    if (!$run) {
      my (@permissions, $error) = GetPermissions($user);
      if (!$error) {
        print start_form(-name=>'InviteUser'),
          h2('Invite User'),
          "Email: ", textfield(-name=>'email'),
          h4('Which permissions would you like to give this person?');
        for (my $i = 0; $i < $#permissions; $i++) {
	  my $permission = @permissions[$i];
	  print "<input type=\"checkbox\" name=\"$permission\"/> $permission <br/>";
	  if ($i == ($#permissions - 1)) {
            print p,
              hidden(-name=>'run',-default=>['1']),
              hidden(-name=>'act',-default=>['invite-user']),
              submit,
              end_form,
              hr;
	  } 
        }
      } else {
        print "<p>Something went wrong while loading permissions (error: $error). Please reload the page</p>";
      }
    } else {
      my (@permissions, $error) = GetPermissions($user);
      my $invitee_perms;
      if (!$error) {
	$invitee_perms = join(",", map { defined($_) ? $_  : "" } grep {defined(param($_))} @permissions);
      }
      print "<p> your permissions are: $invitee_perms okay";
      my $email=param('email');
      my $error;
      my @chars = ("A".."Z", "a".."z", 1..9); 
      my $key;
      $key .= $chars[rand @chars] for 1..8; 
      $error=UserInvite($key,$email,$user,$invitee_perms);
      if ($error) {
        print "Can't invite user because: $error";
      } else {	
        print "Invited user $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>"; 
}
=cut

if ($action eq "give-opinion-data") { 
  if (!UserCan($user, "give-opinion-data")){
    print h2("you do not have the required permissions to give opinion data");
  } else{
    if (!$run) {
        print header(-expires=>'now');

        print "<html>";
        print "<head>";
        print "<title>Give Opinion Data</title>";
        print "</head>";


        print "<body>";

        print "<script>";
        print "\nvar field1 ;";
        print "\n var field2;";
        print "\nvar x;";
        print "\nfunction getLocation() {";
        print "\n  if (navigator.geolocation) {";
        print "        navigator.geolocation.getCurrentPosition(showPosition);";
        print "    } else {";
        print "        x.innerHTML = 'Geolocation is not supported by this browser.';";
        print    "} };\n";
        print "function showPosition(position){";
        print "   field1.value = position.coords.latitude;";
        print "   field2.value = position.coords.longitude;";
        print "};";

        print "\nwindow.onload = function() {";
        print "  field1 = document.getElementById('latfield');";
        print "  field2 = document.getElementById('longfield');";
        print "  var x = document.getElementById('demo');";
        print "  getLocation()";
        print "};\n";
        print "</script>\n";
        print ;
        print "\n";
	print start_form(-name=>'GiveOpinionData'),
                h2('Color the current location with opinion data. The value -1 corresponds to red, 0 corresponds to white, and 1 corresponds to blue'),
                        "color: ", textfield(-name=>'color'),
                        p,
                                "Latitude: ", textfield(-name=>'lati', -id=>'latfield'),
                                p,
                                        "Longitude: ", textfield(-name=>'longe', -id=>'longfield'),
                                                p,
                                                        hidden(-name=>'run',-default=>['1']),
                                                          hidden(-name=>'act',-default=>['give-opinion-data']),
                                                                submit,
                                                                      end_form,
                                                                            hr;
    } else {
      my $color=param('color');
      my $long=param('longe');
      my $lat=param('lati');
      my $error;
      $error=UserGiveOpinionData($user,$color,$lat,$long);
      if ($error) {
        print "Can't give opinion data because: $error";
      } else {
        print "Opinion data with the color $color has been provided succesfully\n";
      }
    }
  }
print h2("Giving Location Opinion Data Is Unimplemented");
}

if ($action eq "give-cs-ind-data") { 
  print h2("Giving Crowd-sourced Individual Geolocations Is Unimplemented");
}

#
# ADD-USER
#
# User Add functionaltiy 
#
#
#
#
if ($action eq "add-user") { 
  if (!UserCan($user,"add-users") && !UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to add users.');
  } else {
    if (!$run) { 
      print start_form(-name=>'AddUser'),
	h2('Add User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      "Email: ", textfield(-name=>'email'),
		p,
		  "Password: ", textfield(-name=>'password'),
		    p,
		      hidden(-name=>'run',-default=>['1']),
			hidden(-name=>'act',-default=>['add-user']),
			  submit,
			    end_form,
			      hr;
    } else {
      my $name=param('name');
      my $email=param('email');
      my $password=param('password');
      my $error;
      $error=UserAdd($name,$password,$email,$user);
      if ($error) { 
	print "Can't add user because: $error";
      } else {
	print "Added user $name $email as referred by $user\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}

#
# DELETE-USER
#
# User Delete functionaltiy 
#
#
#
#
if ($action eq "delete-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to delete users.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'DeleteUser'),
	h2('Delete User'),
	  "Name: ", textfield(-name=>'name'),
	    p,
	      hidden(-name=>'run',-default=>['1']),
		hidden(-name=>'act',-default=>['delete-user']),
		  submit,
		    end_form,
		      hr;
    } else {
      my $name=param('name');
      my $error;
      $error=UserDel($name);
      if ($error) { 
	print "Can't delete user because: $error";
      } else {
	print "Deleted user $name\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# ADD-PERM-USER
#
# User Add Permission functionaltiy 
#
#
#
#
if ($action eq "add-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'AddUserPerm'),
	h2('Add User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['add-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=GiveUserPerm($name,$perm);
      if ($error) { 
	print "Can't add permission to user because: $error";
      } else {
	print "Gave user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}


#
# REVOKE-PERM-USER
#
# User Permission Revocation functionaltiy 
#
#
#
#
if ($action eq "revoke-perm-user") { 
  if (!UserCan($user,"manage-users")) { 
    print h2('You do not have the required permissions to manage user permissions.');
  } else {
    if (!$run) { 
      #
      # Generate the add form.
      #
      print start_form(-name=>'RevokeUserPerm'),
	h2('Revoke User Permission'),
	  "Name: ", textfield(-name=>'name'),
	    "Permission: ", textfield(-name=>'permission'),
	      p,
		hidden(-name=>'run',-default=>['1']),
		  hidden(-name=>'act',-default=>['revoke-perm-user']),
		  submit,
		    end_form,
		      hr;
      my ($table,$error);
      ($table,$error)=PermTable();
      if (!$error) { 
	print "<h2>Available Permissions</h2>$table";
      }
    } else {
      my $name=param('name');
      my $perm=param('permission');
      my $error=RevokeUserPerm($name,$perm);
      if ($error) { 
	print "Can't revoke permission from user because: $error";
      } else {
	print "Revoked user $name permission $perm\n";
      }
    }
  }
  print "<p><a href=\"rwb.pl?act=base&run=1\">Return</a></p>";
}



#
#
#
#
# Debugging output is the last thing we show, if it is set
#
#
#
#

print "</center>" if !$debug;

#
# Generate debugging output if anything is enabled.
#
#
if ($debug) {
  print hr, p, hr,p, h2('Debugging Output');
  print h3('Parameters');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(param($_)) } param();
  print "</menu>";
  print h3('Cookies');
  print "<menu>";
  print map { "<li>$_ => ".escapeHTML(cookie($_))} cookie();
  print "</menu>";
  my $max= $#sqlinput>$#sqloutput ? $#sqlinput : $#sqloutput;
  print h3('SQL');
  print "<menu>";
  for (my $i=0;$i<=$max;$i++) { 
    print "<li><b>Input:</b> ".escapeHTML($sqlinput[$i]);
    print "<li><b>Output:</b> $sqloutput[$i]";
  }
  print "</menu>";
}

print end_html;

#
# The main line is finished at this point. 
# The remainder includes utilty and other functions
#

#
# Create a list of all the cycles
#

sub Portfolios {
  my @rows;
  my $out;
  eval {
    @rows = ExecSQL($dbuser, $dbpasswd, "select name from user_portfolios where owner=?", undef,@_);
  };

  if ($@) {
    return (undef, $@);
  } else {
    $out = "";
    $out = join("\t", map { defined($_) ? @{$_} : "(null)" } @rows);
    return ($out, $@);
  }

}

#
# Generate a table of nearby committees
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Committees {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @cycles = split(/,/, $cycle);
  my @rows;
  my $first = "select latitude, longitude, cmte_nm, cmte_pty_affiliation, cmte_st1, cmte_st2, cmte_city, cmte_st, cmte_zip from cs339.committee_master natural join cs339.cmte_id_to_geo where cycle in (";
  my $second = join(',', map {"?"} @cycles);
  my $sqlStatement = $first.$second.") and latitude>? and latitude<? and longitude>? and longitude<?"; 
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, $sqlStatement,undef,@cycles,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("committee_data","2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("committee_data","2D",@rows),$@);
    }
  }
}

# 
# Get the total money for comm to comm
#
 
sub CommToComm {
  my ($latne,$longne,$latsw,$longsw,$cycle) = @_;
  my @rows;
  my @cycles = split(/,/, $cycle);
  my $first = "select cmte_pty_affiliation, sum(transaction_amnt) from cs339.committee_master natural join cs339.cmte_id_to_geo natural join cs339.comm_to_comm where cycle in ("; 
  my $second = join(',', map {"?"} @cycles);
  my $sqlStatement = $first.$second.") and latitude>? and latitude<? and longitude>? and longitude<? group by cmte_pty_affiliation";
  eval {
    @rows = ExecSQL($dbuser, $dbpasswd, $sqlStatement, undef,@cycles,$latsw,$latne,$longsw,$longne);
  };
  if ($@) {
    return (undef,$@);
  } else {
    return (MakeRaw("comm_to_comm_data","2D",@rows),$@);
  }	

}

# 
# # Get the total money for comm to cand
#
 
sub CommToCand {
  my ($latne,$longne,$latsw,$longsw,$cycle) = @_;
  my @rows;
  my @cycles = split(/,/, $cycle);
  my $first = "select cmte_pty_affiliation, sum(transaction_amnt) from cs339.committee_master natural join cs339.cmte_id_to_geo natural join cs339.comm_to_cand where cycle in (";
  my $second = join(',', map {"?"} @cycles);
  my $sqlStatement = $first.$second.") and latitude>? and latitude<? and longitude>? and longitude<? group by cmte_pty_affiliation";
  eval {
    @rows = ExecSQL($dbuser, $dbpasswd, $sqlStatement, undef,@cycles,$latsw,$latne,$longsw,$longne);
  };
  if ($@) {
    return (undef,$@);
  } else {
    return (MakeRaw("comm_to_cand_data","2D",@rows),$@);
  }     
}
#
# Generate a table of nearby candidates
# ($table|$raw,$error) = Committees(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Candidates {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @cycles = split(/,/, $cycle);
  my @rows;
  my $first = "select latitude, longitude, cand_name, cand_pty_affiliation, cand_st1, cand_st2, cand_city, cand_st, cand_zip from cs339.candidate_master natural join cs339.cand_id_to_geo where cycle in (";
  my $second = join(',', map {"?"} @cycles);
  my $sqlStatement = $first.$second.") and latitude>? and latitude<? and longitude>? and longitude<?";
  eval {
    @rows = ExecSQL($dbuser, $dbpasswd, $sqlStatement,undef,@cycles,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") {
      return (MakeTable("candidate_data", "2D",
			["latitude", "longitude", "name", "party", "street1", "street2", "city", "state", "zip"],
			@rows),$@);
    } else {
      return (MakeRaw("candidate_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby individuals
#
# Note that the handout version does not integrate the crowd-sourced data
#
# ($table|$raw,$error) = Individuals(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Individuals {
  my ($latne,$longne,$latsw,$longsw,$cycle,$format) = @_;
  my @cycles = split(/,/, $cycle);
  my @rows;
  my $first = "select latitude, longitude, name, city, state, zip_code, employer, transaction_amnt from cs339.individual natural join cs339.ind_to_geo where cycle in (";
  my $second = join(',', map {"?"} @cycles);
  my $sqlStatement = $first.$second.") and latitude>? and latitude<? and longitude>? and longitude<?";
  eval {
    @rows = ExecSQL($dbuser, $dbpasswd, $sqlStatement,undef,@cycles,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("individual_data", "2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("individual_data","2D",@rows),$@);
    }
  }
}


#
# Generate a table of nearby opinions
#
# ($table|$raw,$error) = Opinions(latne,longne,latsw,longsw,cycle,format)
# $error false on success, error string on failure
#
sub Opinions {
  my ($latne, $longne, $latsw, $longsw, $cycle,$format) = @_;
  my @rows;
  eval { 
    @rows = ExecSQL($dbuser, $dbpasswd, "select latitude, longitude, color from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne);
  };
  
  if ($@) { 
    return (undef,$@);
  } else {
    if ($format eq "table") { 
      return (MakeTable("opinion_data","2D",
			["latitude", "longitude", "name", "city", "state", "zip", "employer", "amount"],
			@rows),$@);
    } else {
      return (MakeRaw("opinion_data","2D",@rows),$@);
    }
  }
}

#
## Gets the average and standard deviation of colors on the on-screen map
#
sub AvgStddevColor{
  my ($latne, $longne, $latsw, $longsw) = @_;
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select avg(color), stddev(color) from rwb_opinions where latitude>? and latitude<? and longitude>? and longitude<?",undef,$latsw,$latne,$longsw,$longne); };
  if ($@) { 
    return (undef,$@);
  } else {
    return (@rows,$@);
  }
}

#
## Give opinion data for a locaiton
## call with color, latitude, and longitude
##
## returns false on success, error string on failure
##
## UserGiveOpinionData($color, $latitude, $longitude, $submitter)
##

sub UserGiveOpinionData {
  my ($user,$color,$lat,$long) = @_;
    eval { ExecSQL($dbuser,$dbpasswd,
                             "insert into rwb_opinions (submitter,color,latitude,longitude) values (?,?,?,?)",undef,$user,$color,$lat,$long);};
                              return $@;
}

#
# Generate a table of available permissions
# ($table,$error) = PermTable()
# $error false on success, error string on failure
#
sub PermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select action from rwb_actions"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("perm_table",
		      "2D",
		     ["Perm"],
		     @rows),$@);
  }
}

#
# Generate a table of users
# ($table,$error) = UserTable()
# $error false on success, error string on failure
#
sub UserTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select name, email from rwb_users order by name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("user_table",
		      "2D",
		     ["Name", "Email"],
		     @rows),$@);
  }
}

#
# Generate a table of users and their permissions
# ($table,$error) = UserPermTable()
# $error false on success, error string on failure
#
sub UserPermTable {
  my @rows;
  eval { @rows = ExecSQL($dbuser, $dbpasswd, "select rwb_users.name, rwb_permissions.action from rwb_users, rwb_permissions where rwb_users.name=rwb_permissions.name order by rwb_users.name"); }; 
  if ($@) { 
    return (undef,$@);
  } else {
    return (MakeTable("userperm_table",
		      "2D",
		     ["Name", "Permission"],
		     @rows),$@);
  }
}

#
# Add a user
# call with name,password
#
# returns false on success, error string on failure.
# 
# AddUser($name,$password)
#
sub AddUser { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into portfolio_users (name,password) values (?,?)",undef,@_);};
  return $@;
}

#
# Add a portfolio for the given user
#
sub AddPortfolio {
  eval { ExecSQL($dbuser,$dbpasswd,
                 "insert into user_portfolios (owner, name, cash) values (?,?,?)",undef,@_);};
  return $@;
}

#
# Get the permissions of a specific user
#
sub GetPermissions {
  my @rows;
  my $out;
  eval { @rows = ExecSQL($dbuser,$dbpasswd, "select action from rwb_permissions where name=?", undef,@_);};
  if ($@) {
    return (undef, $@);
  }
  my @permissions = map { defined($_) ? @{$_}[0] : "(null)" } @rows;
  $out = "";
  $out = join("\t", map { defined($_) ? @{$_} : "(null)" } @rows);
  return (@permissions, $@);
}
#
## Invite a user
## call with email
##
## returns false on success, error string on failure.
## 
## UserInvite($key,$email,$referrer)
##
sub UserInvite {
  my ($key, $email, $user, $permissions) = @_; 
  eval { ExecSQL($dbuser,$dbpasswd,
                 "insert into invite_users (key,email,referer,permissions) values (?,?,?,?)",undef,$key, $email, $user,$permissions);};
  my $body = "<div> You are invited to participate in rwb. <a href=\"https://murphy.wot.eecs.northwestern.edu/~jsb956/rwb/rwb.pl?act=sign-up&key=$key\"> Join here </a> </div>";
  open(MAIL, "| /usr/sbin/sendmail -t");
  print MAIL "To: $email\n";
  print MAIL "From: jeffreybirori2019\@u.northwestern.edu\n";
  print MAIL "Content-Type: text/html\n";
  print MAIL "Subject: RWB Signup\n\n";
  print MAIL $body;
  close(MAIL);
  return $@;
}

#
# Delete a user
# returns false on success, $error string on failure
# 
sub UserDel { 
  eval {ExecSQL($dbuser,$dbpasswd,"delete from rwb_users where name=?", undef, @_);};
  return $@;
}


#
# Give a user a permission
#
# returns false on success, error string on failure.
# 
# GiveUserPerm($name,$perm)
#
sub GiveUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "insert into rwb_permissions (name,action) values (?,?)",undef,@_);};
  return $@;
}

#
# Revoke a user's permission
#
# returns false on success, error string on failure.
# 
# RevokeUserPerm($name,$perm)
#
sub RevokeUserPerm { 
  eval { ExecSQL($dbuser,$dbpasswd,
		 "delete from rwb_permissions where name=? and action=?",undef,@_);};
  return $@;
}

#
#
# Check to see if user and password combination exist
#
# $ok = ValidUser($user,$password)
#
#
sub ValidUser {
  my ($user,$password)=@_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from portfolio_users where name=? and password=?","COL",$user,$password);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}

#
# Check to see if the portfolio exists for the given user
#
sub ValidPort {
  my ($portfolio, $owner)=@_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from user_portfolios where name=? and owner=?","COL",$portfolio,$owner);};
  if ($@) {
    return 0;
  } else {
    return $col[0]>0;
  } 
}

sub ValidPassword {
  my ($password)=@_;
  my @col;
  eval {@col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where password=?","COL",$password);};
  if ($@) {
    return 0;
  } else {
    return !($col[0]>0);
  }
}

sub ValidSignUp {
  my ($password, $email, $name) = @_;
  my @col;
  eval {
    @col=ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_users where password=? or email=? or name=?", "COL", $password,$email,$name  );};
  if ($@) {
    return 0;
  } else {
    return !($col[0]>0);
  }
}

sub RightUser {
  my ($email, $key) = @_;
  my @col;
  eval {@col = ExecSQL($dbuser,$dbpasswd, "select count(*) from invite_users where key=? and email=?", "COL", $key, $email);};
  if ($@) {
    return 0;
  } else {
    return ($col[0]>0);
  }
}

sub GetReferrerAndPerms {
  my ($key, $name) = @_;
  # Keys are unique so there will only be one row
  my @rows;
  eval { @rows = ExecSQL($dbuser,$dbpasswd, "select referer,permissions from invite_users where key=?", undef, $key);};
  
  if ($@) {
    return (undef, undef, $@);
  } else {
    my $referrer = @{@rows[0]}[0];
    my $permissions = @{@rows[0]}[1];
    my @permissions = split(/,/, $permissions);
    return ($referrer, @permissions, $@);
  }   
}

sub DeleteFromInvites {
  my ($key) = @_;
  eval {ExecSQL($dbuser,$dbpasswd,"delete from invite_users where key=?", undef, $key);};
  return $@;
}

sub ValidKey {
  my ($key) = @_;
  my @col;
  eval {@col = ExecSQL($dbuser,$dbpasswd, "select count(*) from invite_users where key=?", "COL", $key);};
  if ($@) {
    return 0;
  } else {
    return ($col[0]>0);
  } 
}

#
#
# Check to see if user can do some action
#
# $ok = UserCan($user,$action)
#
sub UserCan {
  my ($user,$action)=@_;
  my @col;
  eval {@col= ExecSQL($dbuser,$dbpasswd, "select count(*) from rwb_permissions where name=? and action=?","COL",$user,$action);};
  if ($@) { 
    return 0;
  } else {
    return $col[0]>0;
  }
}





#
# Given a list of scalars, or a list of references to lists, generates
# an html table
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
# $headerlistref points to a list of header columns
#
#
# $html = MakeTable($id, $type, $headerlistref,@list);
#
sub MakeTable {
  my ($id,$type,$headerlistref,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  if ((defined $headerlistref) || ($#list>=0)) {
    # if there is, begin a table
    #
    $out="<table id=\"$id\" border>";
    #
    # if there is a header list, then output it in bold
    #
    if (defined $headerlistref) { 
      $out.="<tr>".join("",(map {"<td><b>$_</b></td>"} @{$headerlistref}))."</tr>";
    }
    #
    # If it's a single row, just output it in an obvious way
    #
    if ($type eq "ROW") { 
      #
      # map {code} @list means "apply this code to every member of the list
      # and return the modified list.  $_ is the current list member
      #
      $out.="<tr>".(map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>" } @list)."</tr>";
    } elsif ($type eq "COL") { 
      #
      # ditto for a single column
      #
      $out.=join("",map {defined($_) ? "<tr><td>$_</td></tr>" : "<tr><td>(null)</td></tr>"} @list);
    } else { 
      #
      # For a 2D table, it's a bit more complicated...
      #
      $out.= join("",map {"<tr>$_</tr>"} (map {join("",map {defined($_) ? "<td>$_</td>" : "<td>(null)</td>"} @{$_})} @list));
    }
    $out.="</table>";
  } else {
    # if no header row or list, then just say none.
    $out.="(none)";
  }
  return $out;
}


#
# Given a list of scalars, or a list of references to lists, generates
# an HTML <pre> section, one line per row, columns are tab-deliminted
#
#
# $type = undef || 2D => @list is list of references to row lists
# $type = ROW   => @list is a row
# $type = COL   => @list is a column
#
#
# $html = MakeRaw($id, $type, @list);
#
sub MakeRaw {
  my ($id, $type,@list)=@_;
  my $out;
  #
  # Check to see if there is anything to output
  #
  $out="<pre id=\"$id\">\n";
  #
  # If it's a single row, just output it in an obvious way
  #
  if ($type eq "ROW") { 
    #
    # map {code} @list means "apply this code to every member of the list
    # and return the modified list.  $_ is the current list member
    #
    $out.=join("\t",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } elsif ($type eq "COL") { 
    #
    # ditto for a single column
    #
    $out.=join("\n",map { defined($_) ? $_ : "(null)" } @list);
    $out.="\n";
  } else {
    #
    # For a 2D table
    #
    foreach my $r (@list) { 
      $out.= join("\t", map { defined($_) ? $_ : "(null)" } @{$r});
      $out.="\n";
    }
  }
  $out.="</pre>\n";
  return $out;
}

#
# @list=ExecSQL($user, $password, $querystring, $type, @fill);
#
# Executes a SQL statement.  If $type is "ROW", returns first row in list
# if $type is "COL" returns first column.  Otherwise, returns
# the whole result table as a list of references to row lists.
# @fill are the fillers for positional parameters in $querystring
#
# ExecSQL executes "die" on failure.
#
sub ExecSQL {
  my ($user, $passwd, $querystring, $type, @fill) =@_;
  if ($debug) { 
    # if we are recording inputs, just push the query string and fill list onto the 
    # global sqlinput list
    push @sqlinput, "$querystring (".join(",",map {"'$_'"} @fill).")";
  }
  my $dbh = DBI->connect("DBI:Oracle:",$user,$passwd);
  if (not $dbh) { 
    # if the connect failed, record the reason to the sqloutput list (if set)
    # and then die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't connect to the database because of ".$DBI::errstr."</b>";
    }
    die "Can't connect to database because of ".$DBI::errstr;
  }
  my $sth = $dbh->prepare($querystring);
  if (not $sth) { 
    #
    # If prepare failed, then record reason to sqloutput and then die
    #
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't prepare '$querystring' because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't prepare $querystring because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  if (not $sth->execute(@fill)) { 
    #
    # if exec failed, record to sqlout and die.
    if ($debug) { 
      push @sqloutput, "<b>ERROR: Can't execute '$querystring' with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr."</b>";
    }
    my $errstr="Can't execute $querystring with fill (".join(",",map {"'$_'"} @fill).") because of ".$DBI::errstr;
    $dbh->disconnect();
    die $errstr;
  }
  #
  # The rest assumes that the data will be forthcoming.
  #
  #
  my @data;
  if (defined $type and $type eq "ROW") { 
    @data=$sth->fetchrow_array();
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","ROW",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  my @ret;
  while (@data=$sth->fetchrow_array()) {
    push @ret, [@data];
  }
  if (defined $type and $type eq "COL") { 
    @data = map {$_->[0]} @ret;
    $sth->finish();
    if ($debug) {push @sqloutput, MakeTable("debug_sqloutput","COL",undef,@data);}
    $dbh->disconnect();
    return @data;
  }
  $sth->finish();
  if ($debug) {push @sqloutput, MakeTable("debug_sql_output","2D",undef,@ret);}
  $dbh->disconnect();
  return @ret;
}


######################################################################
#
# Nothing important after this
#
######################################################################

# The following is necessary so that DBD::Oracle can
# find its butt
#
BEGIN {
  unless ($ENV{BEGIN_BLOCK}) {
    use Cwd;
    $ENV{ORACLE_BASE}="/raid/oracle11g/app/oracle/product/11.2.0.1.0";
    $ENV{ORACLE_HOME}=$ENV{ORACLE_BASE}."/db_1";
    $ENV{ORACLE_SID}="CS339";
    $ENV{LD_LIBRARY_PATH}=$ENV{ORACLE_HOME}."/lib";
    $ENV{BEGIN_BLOCK} = 1;
    exec 'env',cwd().'/'.$0,@ARGV;
  }
}

