module TextEditorComponent exposing (ExternalMessage(..), Model, Msg, init, update, view)

import ComponentResult exposing (ComponentResult)
import Html exposing (Html, button, div, input, text)
import Html.Attributes exposing (value)
import Html.Events exposing (onClick, onInput)
import Task
import Time exposing (Posix)


type alias Model =
    { value : String
    , revertValue : String
    , acceptedAt : Maybe Posix
    }


init : String -> ComponentResult Model msg external err
init value =
    ComponentResult.withModel { value = value, revertValue = value, acceptedAt = Nothing }


type Msg
    = UpdateValue String
    | UpdateAcceptedAt Posix
    | Revert
    | Accept
    | Error


type ExternalMessage
    = ValueAccepted String
    | ValueReverted String


update : Msg -> Model -> ComponentResult Model Msg ExternalMessage String
update msg model =
    case msg of
        UpdateValue string ->
            ComponentResult.withModel { model | value = string }

        UpdateAcceptedAt posix ->
            ComponentResult.withModel { model | acceptedAt = Just posix }

        Revert ->
            ComponentResult.withModel { model | value = model.revertValue }
                |> ComponentResult.withExternalMsg (ValueReverted model.revertValue)

        Accept ->
            ComponentResult.withModel { model | revertValue = model.value }
                |> ComponentResult.withExternalMsg (ValueAccepted model.value)
                |> ComponentResult.withCmd (Time.now |> Task.perform UpdateAcceptedAt)

        Error ->
            ComponentResult.justError "Error Test"


view : Model -> Html Msg
view model =
    div []
        [ input [ onInput UpdateValue, value model.value ] []
        , button [ onClick Accept, Html.Attributes.disabled (model.value == model.revertValue) ] [ text "Accept" ]
        , button [ onClick Revert, Html.Attributes.disabled (model.value == model.revertValue) ] [ text "Revert" ]
        , button [ onClick Error ] [ text "(Error Test)" ]
        ]
