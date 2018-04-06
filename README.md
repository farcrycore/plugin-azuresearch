## Expected format of application.fc.lib.azuresearch.search() filter argument

An array of condition structures:

- `{ text="query here" }` for a general text search
- `{ and=[ array of condition structures ] }`, to require all sub conditions to be met
- `{ or=[ array of condition structures ] }`, to require at least one of sub conditions to be met
- `{ not=[ array of condition structures ] }`, to require that the sub condition not be met
- `{ property="farcry property name", text="query here" }` for a property specific text search
- `{ property="farcry property name", term="value" }` for exact match on the property value
- `{ property="farcry property name", range={ ge|gte|lt|lte=value } }` use one or more operator keys to specify a range match
- `{ property="farcry property name", dateafter=date }` for a simple date filter
- `{ property="farcry property name", in="list,of,terms" }` to match fields that match any of those values