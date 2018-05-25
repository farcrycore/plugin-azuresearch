## Azure Search Plugin

> Easily add sophisticated cloud search capabilities to your website or application using the same integrated Microsoft natural language stack that's used in Bing and Office and that’s been improved over 16 years. Quickly tune search results and construct rich, fine-tuned ranking models to tie search results to business goals. Reliable throughput and storage give you fast search indexing and querying to support time-sensitive search scenarios.
https://azure.microsoft.com/en-us/services/search/

Azure Search Plugin interfaces with the Microsoft Azure Search service to provide search capabilities for any FarCry application. Azure Search is an API based implementation of the Azure Search service, and the plugin works similarly to the FarCry Solr Pro Plugin.

**NOTE: This plugin is compatible with FarCry 7.x and over.**

Azure Search plugin is available under LGPL and compatible with the open source and commercial licenses of FarCry Core.

Base features include:

- config for general settings
- a content type with records for each indexed type, and settings to configure property weighting
- an event handler that triggers index updates on save and delete
- a library in the application scope that encapsulates searches and index updates


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
