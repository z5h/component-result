# ComponentResult

This library is intended to standardize the boilerplate which is often inevitable in
larger Elm apps.

**Q:** I'm an Elm pro, can you give me a **summary**?  
**A:** This like a `Result error (model, Cmd msg, Maybe externalMsg)`.  
It's something you'd return from a "component" operation (e.g. init/update).  
You'd use it instead of returning a `model` or a `(model, Cmd msg)`, or `(model, Cmd msg, Maybe externalMsg)` or `Result error (model, Cmd msg, Maybe externalMsg)`.

**Q:** Do I need it?  
**A:** Yes, if your app is large enough that you have many Pages, made of components, (which in turn might be made of components). This is intended to make connection boilerplate more
consistent and readable.  
No, if your app has 1 view and you don't a set of custom components.

**Q:** **HELP! HELP!** I didn't understand that 👆. Can you explain some questions in-depth?  
**A:** Of course.

**Q:** I thought components aren't allowed or possible in Elm. Is that true?  
**A:** Component is a general term. One _could_ pick a definition that doesn't make sense in Elm
and then say "this thing that doesn't make sense isn't allowed". 🤔 Let's not do that.  
Here, I mean:  
> _A Component is a `model` that can be initialized, and updated.  
In addition to returning a `model` from `init` or `update`, a component can optionally dispatch a `Cmd msg`, and also return an `externalMsg` for the parent/caller to use.   
Importantly, a component's `init`/`update` may return just an `error` , and let the parent/caller decide how to deal with it._

**Q:** What else might happen when I do something a component?  
**A:** Nothing! That's it! We've covered all the bases. We get back a `model` and maybe `Cmd msg` and
maybe an `externalMsg`. Or, things go bad and we just return an `error`.

**Q:** So you're saying doing something to a **Component** will **Result** in the above stuff?  
What should we call it?  
**A:** How about "ComponentResult".

**Q:** And what's the type signature?  
**A:** `ComponentResult model msg externalMsg error`

**Q:** How do I make one?  
```elm
errorResult : ComponentResult model msg externalMsg String
errorResult = justError "Oh no!"
```

**Q:** I never have errors, how do I make one when stuff works?  
```elm
modelResult : ComponentResult MyModel msg externalMsg error
modelResult = withModel myModel
```

**Q:** Can you show me a more complex `ComponentResult`?
```elm
result :ComponentResult MyModel MyMsg ExternalMsg error
result =
    withModel myModel
        |> withCmd myHttpGet
        |> withExternalMsg LoadingData
```

**Q:** Now what?  
**A:** Here's an example of `Main`'s `update` function, where we're updating a Page component.
```elm
update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PageMsg pageMsg ->
            -- this message is for the page.
            -- update the page
            Page.update pageMsg model.pageModel
                -- we got a ComponentResult.
                -- map it's model to our own
                |> ComponentResult.mapModel
                    (\newPageModel -> { pageModel = newPageModel })
                -- map it's msg type to our own our own
                |> ComponentResult.mapMsg PageMsg
                -- handle errors
                |> ComponentResult.resolveError
                    (\err -> {model | lastError = err})
                -- consume externalMsg intended for us
                |> ComponentResult.applyExternalMsg readTheDocsForThis
                -- Now we have a `ComponentResult Model Msg externalMsg err`
                -- If we were a Component ourselves, we'd be done!
                -- Since we're in Main, we can use `resolve`
                -- to return a `( Model, Cmd Msg )`
                |> ComponentResult.resolve
```  


**Q:** So basically you'd use this everywhere and all your `update` and `init` functions
would nest nicely and play nicely together and be standardized?  
**A:** Yes.

**Q:** Is there more?  
**A:** There's `sequence` for sequencing a number of updates on a `ComponentResult`, and `map2Model`
for merging 2 separate `ComponentResult`s together.   
See the examples directory for more examples.
