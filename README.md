# PlantPal
This is an CS senior project for an app designed to help users analyze plants through image analysis/AI to help them identify care methods and needs for plants as well as utilizing resources amongst other plant enthusiasts.


## Plant search (Perenual API)

Plant Search and the plant care details pages use the [Perenual API](https://perenual.com/docs/api).
Plant ID / health analysis (Upload tab) still goes through Plant.id via our Cloudflare worker.

The API key is stored in Firestore at `config/perenual` (field `apiKey`) and loaded
by the app after sign-in, so nobody needs to pass it when running. To test with a
different key locally, override it:

```sh
flutter run --dart-define=PERENUAL_API_KEY=your_key
```

If the key can't be loaded, the search tab shows a "not configured" error instead of crashing.
The free tier allows 100 requests/day, and only species with id <= 3000 return full care data,
so search only runs on Enter, responses are cached on the device for 7 days,
and fields Perenual returns as "Upgrade Plans..." are hidden.
