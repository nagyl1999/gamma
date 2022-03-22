import "/contract/adaptive/Crossroads.gcd"

component Crossroads

//@Strict
@AllowedWaiting 0 .. 1
scenario Blinking initial outputs [
	hot sends priorityOutput.displayYellow
	hot sends secondaryOutput.displayYellow
] [
//	loop (1 .. 2) {
	{
		hot sends priorityOutput.displayNone
		hot sends secondaryOutput.displayNone
		hot delay (500)
	}
	{
		hot sends priorityOutput.displayYellow
		hot sends secondaryOutput.displayYellow
		hot delay (500)
	}
//	}
]

@Strict
@AllowedWaiting 0 .. 1
scenario Init initial outputs [
	hot sends priorityOutput.displayRed
	hot sends secondaryOutput.displayRed
] [
	{
		hot sends priorityOutput.displayGreen
	}
]

//scenario Init [
//	{
//		hot sends priorityOutput.displayRed
//		hot sends secondaryOutput.displayRed
//	}
//	{
//		hot sends priorityOutput.displayGreen
//	}
//]

//@Strict
@AllowedWaiting 0 .. 1
scenario Normal [
//	loop (1 .. 2) {
	{
		hot sends priorityOutput.displayYellow
	}
	{
		hot sends priorityOutput.displayRed
		hot sends secondaryOutput.displayGreen
		hot delay (1000)
	}
	{
		hot delay (2000)
		hot sends secondaryOutput.displayYellow
	}
	{
		hot sends secondaryOutput.displayRed
		hot sends priorityOutput.displayGreen
		hot delay (1000)
	}
//	}
]