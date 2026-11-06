extends Resource
class_name CalendarDefinition
## The calendar the story keeps (Campaign "The clock and the calendar"; the designer, 2026-11-07: "add a
## calendar and time thing as well"). data/calendar.tres is the one in use. The names in it are
## placeholders for the designer's own world; the game asks nothing of them but that there are some.
## A day has 24 hours and an hour 60 minutes, because Light's hours are written by them.

## Each month's name. As many as there are months in the year.
@export var months: Array[String] = ["First Month", "Second Month", "Third Month", "Fourth Month", "Fifth Month", "Sixth Month",
	"Seventh Month", "Eighth Month", "Ninth Month", "Tenth Month", "Eleventh Month", "Twelfth Month"]
@export_range(1, 60) var days_in_a_month: int = 30
## Each day of the week's name.
@export var weekdays: Array[String] = ["First Day", "Second Day", "Third Day", "Fourth Day", "Fifth Day", "Sixth Day", "Seventh Day"]

@export_group("Where the story begins")
## The year, the month (the first is 0), the day of the month (the first is 1), which day of the week that
## is (the first is 0), and the hour of the first morning.
@export var first_year: int = 1
@export_range(0, 60) var first_month: int = 0
@export_range(1, 60) var first_day: int = 1
@export_range(0, 60) var first_weekday: int = 0
@export_range(0, 23) var first_hour: int = 8


## The date on `day_number`, where 1 is the day the story begins: {"year", "month", "day", "weekday"} by
## number, with "month_name" and "weekday_name".
func date_on(day_number: int) -> Dictionary:
	var since: int = maxi(day_number - 1, 0) + (first_day - 1) + first_month * days_in_a_month
	var in_a_year: int = maxi(months.size(), 1) * days_in_a_month
	var year: int = first_year + since / in_a_year
	var month: int = (since % in_a_year) / days_in_a_month
	var weekday: int = (first_weekday + maxi(day_number - 1, 0)) % maxi(weekdays.size(), 1)
	return {"year": year, "month": month, "day": since % in_a_year % days_in_a_month + 1, "weekday": weekday,
		"month_name": months[month] if month < months.size() else "", "weekday_name": weekdays[weekday] if weekday < weekdays.size() else ""}


## "Second Day, 14 of First Month, year 1".
func date_text(day_number: int) -> String:
	var date := date_on(day_number)
	return "%s, %d of %s, year %d" % [date.weekday_name, date.day, date.month_name, date.year]
