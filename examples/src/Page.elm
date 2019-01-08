module Page exposing (Model, Msg, init, update, view)

import ComponentResult exposing (ComponentResult)
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (value)
import Html.Events exposing (onClick, onInput)
import Task
import TextEditorComponent
import Time exposing (Posix)


type alias Model =
    { textEditorA : TextEditorComponent.Model
    , textEditorB : TextEditorComponent.Model
    , status : String
    }


type Index
    = A
    | B


init : ComponentResult Model msg external err
init =
    let
        componentResultA =
            TextEditorComponent.init "A"

        componentResultB =
            TextEditorComponent.init "B"
    in
    -- merge multiple componentResults into our own
    ComponentResult.map2Model
        (\textEditorA textEditorB ->
            { textEditorA = textEditorA, textEditorB = textEditorB, status = "" }
        )
        componentResultA
        componentResultB


type Msg
    = TextEditorComponentMsg Index TextEditorComponent.Msg


update : Msg -> Model -> ComponentResult Model Msg externamMsg err
update msg model =
    case msg of
        TextEditorComponentMsg index textEditorComponentMsg ->
            case index of
                A ->
                    TextEditorComponent.update textEditorComponentMsg model.textEditorA
                        -- map the TextEditorComponent's model to our own
                        |> ComponentResult.mapModel
                            (\newA -> { model | textEditorA = newA })
                        -- map the TextEditorComponent's cmd to our own
                        |> ComponentResult.mapMsg
                            (TextEditorComponentMsg A)
                        -- apply a TextEditorComponent's external msg to our own schema of model & msg
                        |> ComponentResult.applyExternalMsg
                            (\externalMsg result ->
                                case externalMsg of
                                    TextEditorComponent.ValueAccepted string ->
                                        result
                                            |> ComponentResult.mapModel
                                                (\resultModel ->
                                                    { resultModel
                                                        | status = "Editor A value accepted: " ++ string
                                                    }
                                                )

                                    TextEditorComponent.ValueReverted string ->
                                        result
                                            |> ComponentResult.mapModel
                                                (\resultModel ->
                                                    { resultModel
                                                        | status = "Editor A value reverted: " ++ string
                                                    }
                                                )
                            )
                        -- In the case of an error, the caller takes full responsibility in resolving it
                        |> ComponentResult.resolveError
                            (\error ->
                                ComponentResult.withModel { model | status = "Error triggered in Editor A" }
                            )

                B ->
                    TextEditorComponent.update textEditorComponentMsg model.textEditorB
                        -- map the TextEditorComponent's model to our own
                        |> ComponentResult.mapModel
                            (\newB -> { model | textEditorB = newB })
                        -- map the TextEditorComponent's cmd to our own
                        |> ComponentResult.mapMsg
                            (TextEditorComponentMsg B)
                        -- apply a TextEditorComponent's external msg to our own schema of model & msg
                        |> ComponentResult.applyExternalMsg
                            (\externalMsg result ->
                                case externalMsg of
                                    TextEditorComponent.ValueAccepted string ->
                                        result
                                            |> ComponentResult.mapModel
                                                (\resultModel ->
                                                    { resultModel
                                                        | status = "Editor B value accepted: " ++ string
                                                    }
                                                )

                                    TextEditorComponent.ValueReverted string ->
                                        result
                                            |> ComponentResult.mapModel
                                                (\resultModel ->
                                                    { resultModel
                                                        | status = "Editor B value reverted: " ++ string
                                                    }
                                                )
                            )
                        -- In the case of an error, the caller takes full responsibility in resolving it
                        |> ComponentResult.resolveError
                            (\error ->
                                ComponentResult.withModel { model | status = "Error triggered in Editor B" }
                            )


view : Model -> Html Msg
view model =
    div []
        [ TextEditorComponent.view model.textEditorA |> Html.map (TextEditorComponentMsg A)
        , Html.br [] []
        , TextEditorComponent.view model.textEditorB |> Html.map (TextEditorComponentMsg B)
        , Html.br [] []
        , Html.text model.status
        ]
