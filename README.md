# joheulttaeda

추억과 아이디어를 사진 카드와 폴더 형태로 정리하는 SwiftUI iOS 앱입니다.

## 구현된 화면

- Memory와 Idea를 보여주는 홈 화면
- 필터와 폴더 카드로 구성된 Idea 피드
- 폴더를 선택했을 때 사진이 펼쳐지는 상세 화면
- Moments, Days, Months, Threads로 구성된 Memory 화면
- Share Extension을 통한 사진, 영상, Instagram 링크 가져오기
- 가져온 미디어의 Application Support 영구 저장과 SwiftData 메타데이터 관리

## Idea 공유 가져오기

Instagram이나 사진 앱의 공유 시트에서 `Idea에 저장`을 선택하면 Share Extension이
공유 항목을 `group.com.folitune.joheulttaeda` App Group의 `Incoming` 디렉터리에
임시 저장합니다. 메인 앱은 실행되거나 활성화될 때 작업을 소비합니다.

- 사진: `Application Support/IdeaMedia/<folder>/<item>/original.*`와 `thumbnail.jpg` 저장
- 영상: 원본 영상과 첫 장면 기반 `thumbnail.jpg` 저장
- Instagram URL: resolver가 없으면 링크 카드로 저장
- 같은 파일 또는 같은 Instagram URL은 중복 등록하지 않음

Instagram 공식 API를 사용하는 백엔드를 연결하려면 메인 앱 Info.plist에
`InstagramImportResolverURL`을 설정합니다. 앱은 해당 endpoint에 아래 요청을 보냅니다.

```json
{
  "sourceURL": "https://www.instagram.com/reel/.../"
}
```

응답의 미디어 URL은 HTTPS여야 합니다.

```json
{
  "assets": [
    {
      "url": "https://cdn.example.com/media.mp4",
      "mediaType": "video"
    }
  ]
}
```

endpoint를 설정하지 않으면 게시물 HTML을 스크래핑하지 않고 Instagram 링크만 저장합니다.

## Instagram oEmbed 인앱 플레이어

Instagram 링크 카드를 누르면 앱은 `InstagramOEmbedResolverURL`로 설정된 백엔드에
원본 URL을 보내고, 응답의 공식 oEmbed HTML을 `WKWebView`에 표시합니다. endpoint가
아직 설정되지 않은 개발 환경에서는 동일한 공개 게시물의 Instagram 공식 `/embed/`
화면을 직접 표시합니다. 따라서 로컬 백엔드 없이도 지원되는 공개 사진과 릴스를 확인할
수 있습니다. Meta 토큰은 iOS 앱이나 저장소에 포함하지 않습니다.

운영에서 oEmbed API를 사용하려면 백엔드는 Node.js 20.6 이상에서 별도 패키지 설치 없이
실행할 수 있습니다.

```bash
cd backend
cp .env.example .env
```

`backend/.env`의 `META_OEMBED_ACCESS_TOKEN`에는 대화나 저장소에 노출되지 않은 새
App Access Token을 입력합니다. 해당 Meta 앱은 Business Verification 완료,
`oEmbed Read` Advanced Access 승인, Live 상태여야 합니다. 필요하면
`META_GRAPH_API_VERSION`도 App Dashboard에서 지원되는 버전으로 변경합니다.

```bash
npm test
npm start
```

서버 endpoint는 다음과 같습니다.

```text
POST /instagram/oembed
Content-Type: application/json

{"sourceURL":"https://www.instagram.com/reel/.../"}
```

성공 응답은 장기 저장하지 않는 embed HTML만 반환합니다.

```json
{
  "html": "<blockquote class=\"instagram-media\" ...></blockquote>"
}
```

iOS 시뮬레이터에서 로컬 서버를 사용할 때 Scheme의 Environment Variables에 아래
값을 추가합니다.

```text
INSTAGRAM_OEMBED_RESOLVER_URL=http://127.0.0.1:8787/instagram/oembed
```

배포 빌드에서는 앱 Target의 Build Settings에서
`INFOPLIST_KEY_InstagramOEmbedResolverURL`을 배포한 HTTPS endpoint로 설정합니다.
백엔드에 `IDEA_EMBED_API_KEY`를 설정했다면 Debug Scheme의
`INSTAGRAM_OEMBED_API_KEY` 또는 동일한 이름의 Info.plist 설정에도 값을 넣어야 합니다.
이 키는 모바일 앱에서 추출될 수 있으므로 운영 환경의 강한 인증 수단이 아니라 기본적인
오용 방지 용도입니다. 운영 서버에는 별도의 rate limit과 필요 시 App Attest 검증을
추가하는 것이 좋습니다.

공개 게시물이라도 비공개·연령 제한·임베드 비활성화 상태이면 oEmbed가 실패하며, 앱은
재시도와 `Instagram에서 열기` 폴백을 제공합니다. Meta 정책에 맞게 oEmbed HTML과
메타데이터는 SwiftData에 영구 저장하지 않고 화면을 열 때마다 가져옵니다.

## 프로젝트 열기

```bash
open joheulttaeda/joheulttaeda.xcodeproj
```

## 저장소 구조

```text
joheulttaeda/
├── backend/         # Instagram oEmbed relay
├── joheulttaeda/    # iOS 앱과 Share Extension
├── .gitignore
└── README.md
```
