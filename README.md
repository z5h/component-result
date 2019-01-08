# ComponentResult

This library is intended to standardize the boilerplate which is often inevitable in
larger Elm apps.

This is likely only of interest to those who have grown their app to include "Pages" or "Components"
, in the sense of modules exposing things like `(Model, Msg, init, update, ...)`.


Following is an example of a Page handling a msg for a subcomponent.  
We update the subcomponent and are able to handle model changes, cmd dispatches, external messages
and error states in a uniform way.

e.g.
```elm
( updatedModel, cmd ) =
    Page.update pageMsg model.pageModel
        --
        -- map the result's model into our own
        |> ComponentResult.mapModel
            (\newPageModel -> { model | pageModel = newPageModel })
        --
        -- map the result's Cmds into our own
        |> ComponentResult.mapMsg PageMsg
        --
        -- consume external messages as we see fit
        |> ComponentResult.applyExternalMsg
            (\externalMsg result ->
                case externalMsg of
                    InterestingPageEvent someEvent ->
                        result
                            |> ComponentResult.mapModel
                                (\resultModel ->
                                    { resultModel | lastInterestingEvent = someEvent }
                                )
            )
        --
        -- in the case of an error status, only this will be run
        |> ComponentResult.resolveError
            (\error ->
                { model | lastError = error }
            )
        --
        -- finally, when things are mapped, and errors and external messages are handled
        -- we can convert the result to a (model, cmds)
        |> ComponentResult.resolve
```

See the examples directory for more examples.
