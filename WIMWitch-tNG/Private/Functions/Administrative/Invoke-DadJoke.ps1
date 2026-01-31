Function Invoke-DadJoke {
    $header = @{accept = 'Application/json' }
    $joke = Invoke-RestMethod -Uri 'https://icanhazdadjoke.com' -Method Get -Headers $header
    return $joke.joke
}
