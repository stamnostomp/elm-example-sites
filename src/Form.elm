module Form exposing (Model, Msg, init, update, view)

import Char exposing (isAlphaNum)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode as Decode


{-| -}
type alias Field =
    { value : String
    , isDirty : Bool
    , errorMessage : Maybe String
    }


type alias Model =
    { username : Field
    , email : Field
    , password : Field
    , confirmPassword : Field
    , agreeToTerms : Bool
    , formSubmitted : Bool
    , formSuccess : Bool
    }


init : Model
init =
    { username = Field "" False Nothing
    , email = Field "" False Nothing
    , password = Field "" False Nothing
    , confirmPassword = Field "" False Nothing
    , agreeToTerms = False
    , formSubmitted = False
    , formSuccess = False
    }



-- UPDATE


type Msg
    = UpdateUsername String
    | UpdateEmail String
    | UpdatePassword String
    | UpdateConfirmPassword String
    | ToggleAgreeToTerms Bool
    | BlurUsername
    | BlurEmail
    | BlurPassword
    | BlurConfirmPassword
    | SubmitForm
    | ResetForm


update : Msg -> Model -> Model
update msg model =
    case msg of
        UpdateUsername value ->
            let
                username =
                    model.username

                updatedUsername =
                    { username | value = value }
            in
            { model | username = updatedUsername }
                |> validateUsernameIfDirty

        -- pipe passes to the last arugement on the right
        UpdateEmail value ->
            let
                email =
                    model.email

                updatedEmail =
                    { email | value = value }
            in
            { model | email = updatedEmail }
                |> validateEmailIfDirty

        UpdatePassword value ->
            let
                password =
                    model.password

                updatedPassword =
                    { password | value = value }
            in
            { model | password = updatedPassword }
                |> validatePasswordIfDirty
                |> validateConfirmPasswordIfDirty

        UpdateConfirmPassword value ->
            let
                confirmPassword =
                    model.confirmPassword

                updatedConfirmPassword =
                    { confirmPassword | value = value }
            in
            { model | confirmPassword = updatedConfirmPassword }
                |> validateConfirmPasswordIfDirty

        ToggleAgreeToTerms value ->
            { model | agreeToTerms = value }

        BlurUsername ->
            let
                username =
                    model.username

                updatedUsername =
                    { username | isDirty = True }
            in
            { model | username = updatedUsername }
                |> validateUsername

        BlurEmail ->
            let
                email =
                    model.email

                updatedEmail =
                    { email | isDirty = True }
            in
            { model | email = updatedEmail }
                |> validateEmail

        BlurPassword ->
            let
                password =
                    model.password

                updatedPassword =
                    { password | isDirty = True }
            in
            { model | password = updatedPassword }
                |> validatePassword

        BlurConfirmPassword ->
            let
                confirmPassword =
                    model.confirmPassword

                updatedConfirmPassword =
                    { confirmPassword | isDirty = True }
            in
            { model | confirmPassword = updatedConfirmPassword }
                |> validateConfirmPassword

        SubmitForm ->
            validateForm { model | formSubmitted = True }
                |> handleSubmission

        ResetForm ->
            init



-- VALIDATION HELPERS


validateUsernameIfDirty : Model -> Model
validateUsernameIfDirty model =
    if model.username.isDirty then
        validateUsername model

    else
        model


validateUsername : Model -> Model
validateUsername model =
    let
        username =
            model.username

        value =
            username.value

        errorMessage =
            if String.length value == 0 then
                Just "Username is required"

            else if String.length value < 3 then
                Just "Username must be at least 3 characters"

            else if String.length value > 20 then
                Just "Username canot be more thne 20 characters long"

            else if not (isAlphaNumeric value) then
                Just "Username can only contain letters and numbers"

            else
                Nothing
    in
    { model | username = { username | errorMessage = errorMessage } }


validateEmailIfDirty : Model -> Model
validateEmailIfDirty model =
    if model.email.isDirty then
        validateEmail model

    else
        model


validateEmail : Model -> Model
validateEmail model =
    let
        email =
            model.email

        value =
            email.value

        errorMessage =
            if String.length value == 0 then
                Just "Email is reqired"

            else if not (String.contains "@" value && String.contains "." value) then
                Just "Please enter a valid email address"

            else
                Nothing
    in
    { model | email = { email | errorMessage = errorMessage } }


validatePasswordIfDirty : Model -> Model
validatePasswordIfDirty model =
    if model.password.isDirty then
        validatePassword model

    else
        model


validatePassword : Model -> Model
validatePassword model =
    let
        password =
            model.password

        value =
            password.value

        errorMessage =
            if String.length value == 0 then
                Just "Password is required "

            else if String.length value < 8 then
                Just "Password must be at least 8 characters long"

            else if not (containsUppercase value && containsLowercase value && containsNumber value) then
                Just "Password must have upper and lower case and at least one number"

            else
                Nothing
    in
    { model | password = { password | errorMessage = errorMessage } }


validateConfirmPasswordIfDirty : Model -> Model
validateConfirmPasswordIfDirty model =
    if model.confirmPassword.isDirty then
        validateConfirmPassword model

    else
        model


validateConfirmPassword : Model -> Model
validateConfirmPassword model =
    let
        confirmPassword =
            model.confirmPassword

        value =
            confirmPassword.value

        errorMessage =
            if String.length value == 0 then
                Just "Please confirm your password"

            else if value /= model.password.value then
                Just "Passwords dont't match"

            else
                Nothing
    in
    { model | confirmPassword = { confirmPassword | errorMessage = errorMessage } }


validateForm : Model -> Model
validateForm model =
    model
        |> validateUsername
        |> validateEmail
        |> validatePassword
        |> validateConfirmPassword


handleSubmission : Model -> Model
handleSubmission model =
    let
        hasErrors =
            model.username.errorMessage
                /= Nothing
                || model.email.errorMessage
                /= Nothing
                || model.password.errorMessage
                /= Nothing
                || model.confirmPassword.errorMessage
                /= Nothing
                || not model.agreeToTerms
    in
    if hasErrors then
        model

    else
        { model | formSuccess = True }



-- STRING VALIDATORS


isAlphaNumeric : String -> Bool
isAlphaNumeric str =
    String.all (\c -> Char.isAlpha c || Char.isDigit c) str


containsUppercase : String -> Bool
containsUppercase str =
    String.any Char.isUpper str


containsLowercase : String -> Bool
containsLowercase str =
    String.any Char.isLower str


containsNumber : String -> Bool
containsNumber str =
    String.any Char.isDigit str



-- VIEW


view : Model -> Html Msg
view model =
    div [ class "form-module" ]
        [ div [ class "form-header" ]
            [ h2 [ class "form-title" ] [ text "User Registration Form" ]
            , p [ class "form-description" ]
                [ text "A form example demonstrating validation, error handling, and form submission." ]
            ]
        , if model.formSuccess then
            viewSuccessMessage model

          else
            viewForm model
        , viewExplanation
        ]


viewForm : Model -> Html Msg
viewForm model =
    Html.form [ class "registration-form", onSubmit SubmitForm ]
        [ div [ class "form-field" ]
            [ label [ class "field-label", for "username" ] [ text "Username" ]
            , input
                [ type_ "text"
                , id "username"
                , class "field-input"
                , classList [ ( "error", model.username.errorMessage /= Nothing && (model.username.isDirty || model.formSubmitted) ) ]
                , placeholder "Choose a username"
                , value model.username.value
                , onInput UpdateUsername
                , onBlur BlurUsername
                ]
                []
            , viewFieldError model.formSubmitted model.username
            ]
        , div [ class "form-field" ]
            [ label [ class "field-label", for "email" ] [ text "Email" ]
            , input
                [ type_ "email"
                , id "email"
                , class "field-input"
                , classList [ ( "error", model.email.errorMessage /= Nothing && (model.email.isDirty || model.formSubmitted) ) ]
                , placeholder "Your email address"
                , value model.email.value
                , onInput UpdateEmail
                , onBlur BlurEmail
                ]
                []
            , viewFieldError model.formSubmitted model.email
            ]
        , div [ class "form-field" ]
            [ label [ class "field-label", for "password" ] [ text "Password" ]
            , input
                [ type_ "password"
                , id "password"
                , class "field-input"
                , classList [ ( "error", model.password.errorMessage /= Nothing && (model.password.isDirty || model.formSubmitted) ) ]
                , placeholder "Create a password"
                , value model.password.value
                , onInput UpdatePassword
                , onBlur BlurPassword
                ]
                []
            , viewFieldError model.formSubmitted model.password
            ]
        , div [ class "form-field" ]
            [ label [ class "field-label", for "confirm-password" ] [ text "Confirm Password" ]
            , input
                [ type_ "password"
                , id "confirm-password"
                , class "field-input"
                , classList [ ( "error", model.confirmPassword.errorMessage /= Nothing && (model.confirmPassword.isDirty || model.formSubmitted) ) ]
                , placeholder "Confirm your password"
                , value model.confirmPassword.value
                , onInput UpdateConfirmPassword
                , onBlur BlurConfirmPassword
                ]
                []
            , viewFieldError model.formSubmitted model.confirmPassword
            ]
        , div [ class "form-checkbox" ]
            [ label [ class "checkbox-container" ]
                [ input
                    [ type_ "checkbox"
                    , checked model.agreeToTerms
                    , onCheck ToggleAgreeToTerms
                    ]
                    []
                , span [ class "checkbox-label" ] [ text "I agree to the Terms and Conditions" ]
                ]
            , if not model.agreeToTerms && model.formSubmitted then
                div [ class "field-error" ] [ text "You must agree to the terms to continue" ]

              else
                text ""
            ]
        , div [ class "form-actions" ]
            [ button [ class "submit-button", type_ "submit" ] [ text "Register" ]
            , button [ class "reset-button", type_ "button", onClick ResetForm ] [ text "Reset" ]
            ]
        ]


viewFieldError : Bool -> Field -> Html Msg
viewFieldError formSubmitted field =
    if (field.isDirty || formSubmitted) && field.errorMessage /= Nothing then
        div [ class "field-error" ] [ text (Maybe.withDefault "" field.errorMessage) ]

    else
        text ""


viewSuccessMessage : Model -> Html Msg
viewSuccessMessage model =
    div [ class "success-message" ]
        [ div [ class "success-icon" ] [ text "✓" ]
        , h3 [] [ text "Registration Successful!" ]
        , p []
            [ text "Thank you for registering, "
            , strong [] [ text model.username.value ]
            , text ". "
            ]
        , p [] [ text "We've sent a confirmation email to: " ]
        , p [ class "success-email" ] [ text model.email.value ]
        , button
            [ class "new-registration-button", onClick ResetForm ]
            [ text "Register Another User" ]
        ]


viewExplanation : Html Msg
viewExplanation =
    div [ class "form-explanation" ]
        [ div [ class "explanation-title" ] [ text "How it works:" ]
        , div [ class "explanation-item" ] [ text "• Model - Tracks form field values, validation state, and submission status" ]
        , div [ class "explanation-item" ] [ text "• Validation - Validates data in real-time and on submission" ]
        , div [ class "explanation-item" ] [ text "• Error Handling - Shows contextual error messages when fields are invalid" ]
        , div [ class "explanation-item" ] [ text "• Form State - Manages the complete lifecycle of the form" ]
        ]
