$(document).ready(function() {
    // Nothing for now
});


//
// NewData is called by the browser after any request
// for data we have initiated completes
//
NewData = function(data) {
// All it does is copy the data that came back from the server
// into the data division of the document.   This is a hidden 
// division we use to cache it locally
	$("#data").html(data);
// Now that the new data is in the document, we use it to
// update our page
	// Insert function here
},

//
// The Google Map calls us back at ViewShift when some aspect
// of the map changes (for example its bounds, zoom, etc)
//
ViewShift = function() {
// Now we make a web request.   Here we are invoking rwb.pl on the 
// server, passing it the act, latne, etc, parameters for the current
// map info, requested data, etc.
// the browser will also automatically send back the cookie so we keep
// any authentication state
// 
// This *initiates* the request back to the server.  When it is done,
// the browser will call us back at the function NewData (given above)
	$.get("rwb.pl",
		{
			act:	"near",
		/*	latne:	ne.lat(),
			longne:	ne.lng(),
			latsw:	sw.lat(),
			longsw:	sw.lng(),
			format:	"raw",
			cycle:	(filteredCycles ? filteredCycles : undefined),
			what:	newWhat*/
		}, NewData);
},

