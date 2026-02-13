# Event Listing Assets

@docs/specs/event-listing.md added submission funtionality for our event listing. In this new mission, we're going to allow sponsors to upload hero image for their events. We'll incorporate the existing SponsorshipAssetFile model and its functionality to handle these uploads. However, it requires refactoring to expand onto new use cases.

## Concern

Extract SponsorshipAssetFile functionality into a reusable concern. Name it `AssetFileUploadable`. This concern will encapsulate the logic for handling file uploads, validations, and associations.

Also, currently SponsorshipAssetFile is referencing ENV variables directly within the model. We need to move this out to config/environments/*.rb files.

We'll use the single bucket for all uploadable models. per-file prefix is currently configured as `c-#{conference.id}/`. We need to have extra prefix for per-model use case.

It's also smelling bad as we're giving the `c-` prefix in multiple places. We should consolidate this logic and allow to set per-usecase.

```ruby
# in SponsorshipAssetFileController
def create
  @asset_file = SponsorshipAssetFile.create!(prefix: "c-#{@conference.id}/") 
end

# in SponsorshipAssetFile
  def copy_to!(conference)
    dst = self.class.create!(prefix: "c-#{conference.id}/", extension: self.extension)
  end
```

### Authorization

The existing authorization code for SponsorshipAssetFile does not need to be changed. This logic is special, because files are uploaded before a Sponsorship record is created.

While the new model, SponsorEventAssetFile, will be created by an estalished Sponsorship session. Therefore, as long as we couple a file with a sponsorship (via SponsorEvent), we can just check sponsorship ownership instead of special logic.

## Agnostic uploader

You need to update the existing browser-side uploader code to support multiple models, and move or rename to indicate its agnostic nature.

## SponsorEventAssetFile

Finally, we'll add an asset file to SponsorEvent model. Unlike Sponsorship model, asset is optional, and we require to be raster image only (png, jpg, webp).

Then, add an uploader to sponsor_events#_form.

## Deliverables

- Refactored SponsorshipAssetFile
- New concern AssetFileUploadable
- SponsorEvent gains ability to upload hero image using the new concern.
  - SponsorEventAssetFile model

## Implementation notes

- Implementor must halt and wait for review once refactoring is done, to ease review process.
- Rails server is up and running. use playwright MCP to verify upload functionality, including existing functions.

## Current Status

Draft
