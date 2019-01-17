# ComponentResult

This library is intended to standardize the boilerplate which is often inevitable in
larger Elm apps.



**Q:** I'm an Elm pro, can you give me a **summary**?  
**A:** This like a `Result error (model, Cmd msg, Maybe externalMsg)`.  
It's something you'd return from a "component" operation (e.g. init/update).  
You'd use it instead of returning a `model` or a `(model, Cmd msg)`, or `(model, Cmd msg, Maybe externalMsg)` or `Result error (model, Cmd msg, Maybe externalMsg)`.

```elm
module MyComponent exposing (init, ...)

type Model = {...}
type Msg = ...
type ExternalMsg = ...

init : ComponentResult Model Msg ExternalMsg err
init = ComponentResult.withModel {...}
      |> ComponentResult.withCmds loadDataHttpGet
      |> ComponentResult.withExternalMsg DataRequested
```
  _  

**Q:** Do I need it?  
**A:** Yes, if your app is large enough that you have many Pages, made of components, (which in turn might be made of components). This is intended to make connection boilerplate more
consistent and readable.  
No, if your app has 1 view and you don't a set of custom components.

  _  


**Q:** **HELP! HELP!** I didn't understand that 👆. Can you explain some questions in-depth?  
**A:** Of course.

  _  

**Q:** I thought components aren't allowed or possible in Elm. Is that true?  
**A:** Component is a general term. One _could_ pick a definition that doesn't make sense in Elm
and then say "this thing that doesn't make sense isn't allowed". 🤔 Let's not do that.  
Here, I mean:  
> _A Component is a `model` that can be initialized, and updated.  
In addition to returning a `model` from `init` or `update`, a component can optionally dispatch a `Cmd msg`, and also return an `externalMsg` for the parent/caller to use.   
Importantly, a component's `init`/`update` may return just an `error` , and let the parent/caller decide how to deal with it._

**Q:** Does a component need a `view` function?  
**A:** Nope. You could wrap a data-store as a component.

  _  

**Q:** What else might happen when I do something to a component?  
**A:** Nothing! That's it! We've covered all the bases. We get back a `model` and maybe `Cmd msg` and
maybe an `externalMsg`. Or, things go bad and we just get an `error`.

_  

**Q:** Wait, why do I need errors? What could go wrong? And if something bad did happen, I can store that info in my model, or notify the caller via externalMsg.  
**A:** Suppose I have a “Paged List” component. And I update it to display the 10th page of data, when there are only 9 pages of data.

What should update return?

Careful, it’s a trick question.  
It’s not up to the component author. A component author might be tempted to “do something reasonable” like, make no change to the model, or set it to the 9th page, or whatever.  
Inevitably someone using the component would have preferred a different behaviour.
So the sensible default, when you ask a component to do something nonsensical, is to simply return an error and let the caller do something sensible. The caller can set it to page 9, or display an error or whatever they want.

  _  

**Q:** So what should we name the **Result**  of doing something to a **Component**?  
**A:** How about "ComponentResult".

  _  

**Q:** And what's the type signature?  
**A:** `ComponentResult model msg externalMsg error`

  _

**Q:** How do I make one?  
**A:** If things go well and you have a model
```elm
modelResult : ComponentResult MyModel msg externalMsg error
modelResult = withModel myModel
```
otherwise
```elm
errorResult : ComponentResult model msg externalMsg String
errorResult = justError "Oh no!"
```

  _  

**Q:** Why is one called **with**Model and the other is **just**Error?  
**A:** `justError` results can't carry any more information. `withModel` can have more info added.

  _  


**Q:** Can you show me a more complex `ComponentResult`?
```elm
result :ComponentResult MyModel MyMsg ExternalMsg error
result =
    withModel myModel
        |> withCmd myHttpGet
        |> withExternalMsg LoadingData
```

  _  

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


  _  

**Q:** So basically you'd use this everywhere and all your `update` and `init` functions
would nest nicely and play nicely together and be standardized?  
**A:** Yes.

  _  

**Q:** Is there more?  
**A:** There's `sequence` for sequencing a number of updates on a `ComponentResult`, and `map2Model`
for merging 2 separate `ComponentResult`s together, and some other things you might eventually need to reach for. See the API docs or the examples directory for more examples.

  _  

**Q:** There seem to be restrictions against batching external messages or adding several of them.
**A:** This is intended. Cmds are run by the elm runtime and we can dispatch as many as we need up
to the main update function for Elm to run. But ... an external message is a note to the caller.
Like, if you had a several important things to tell your boss, and several people under you giving you information, you probably wouldn't schedule meetings for every single item.
You'd batch stuff together, throw some information out, and give your boss high level info packaged up
in a considerate way. Similarly, be nice to you caller. If you are telling them something, wrap up
necessary info cleanly in a single custom message.  
