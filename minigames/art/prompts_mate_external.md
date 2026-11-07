# 혼처 초상 — 다른 AI 에 붙여 넣을 프롬프트

사용자가 보낸 참고 그림(한복 미인화 세 폭)에 맞춰 다시 쓴 것. 한 장마다 공통 화풍이 다 들어 있어 **한 덩어리를 그대로 복사**하면 된다.
결과 파일 이름은 각 제목(`gh_mate_f_1` …)으로 저장 → `art/post.bat <파일> <이름> plain` → `art/gangho/`.
게임은 그림 가장자리 12% 를 잘라 내고 쓴다(`GhArt.portrait`) — 테두리가 잘려도 괜찮다.

- 같은 대화창에서 여섯 장을 이어서 뽑으면 화풍이 맞는다. 두 번째부터 "앞 그림과 같은 화풍으로" 를 덧붙여도 좋다.
- 크기는 세로 2:3(예: 1024×1536).
- 중국 옷으로 바꾸려면 각 프롬프트의 `Joseon-era hanbok ...` 부분을 `Ming-dynasty hanfu ...` 로 바꾼다(게임 배경은 중원 무림).

## 여자 6종

### gh_mate_f_1 — 단아한 규수 (붓)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), flawless soft skin, subtle natural makeup. Vertical 2:3 portrait, waist-up, exactly one young woman, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A graceful young woman of twenty with a calm gentle smile. Glossy black hair parted in the middle and tied in a low chignon with a jade and coral ornate binyeo hairpin and small floral pins. Joseon-era hanbok: a mint green silk jeogori with a pink embroidered collar and gold-patterned cuffs, a deep red chima skirt. She holds a fine calligraphy brush in one hand and a small jade frog-shaped water dropper in the other.
```

### gh_mate_f_2 — 밝은 아가씨 (부채)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), flawless soft skin, subtle natural makeup. Vertical 2:3 portrait, waist-up, exactly one young woman, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A radiant young woman of twenty with a bright happy smile. Voluminous black hair in a high braided updo decorated with colorful silk ribbons, a gold butterfly crown ornament and jeweled flower pins. Joseon-era hanbok: a royal blue silk jeogori richly embroidered with colorful flowers, a purple chima skirt with gold floral patterns, a long tasseled norigae. She holds an open painted silk fan showing a crane, pine trees and red peonies.
```

### gh_mate_f_3 — 차분한 여인 (두 손 모음)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), flawless soft skin, subtle natural makeup. Vertical 2:3 portrait, waist-up, exactly one young woman, slight three-quarter view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A serene young woman of twenty two with a calm thoughtful expression, gazing slightly to the side. Sleek black hair parted in the middle and tied in a low bun with a simple wooden binyeo hairpin and one small flower pin. Joseon-era hanbok: a navy blue damask silk jeogori with subtle woven floral patterns, a white collar and a silver-grey goreum ribbon, a dark green chima skirt, a jade norigae with colorful tassels hanging at the waist. Her hands are folded gently in front of her.
```

### gh_mate_f_4 — 수줍은 처녀 (매화 가지)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), flawless soft skin, subtle natural makeup. Vertical 2:3 portrait, waist-up, exactly one young woman, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A charming young woman of nineteen with a shy sweet smile and slightly lowered eyes. Long black hair in a single braid falling over her shoulder, tied with a red daenggi ribbon, a small silver flower pin above the ear. Joseon-era hanbok: a soft peach silk jeogori with gold-embroidered trim and a coral goreum ribbon, a light pink chima skirt. She holds a small sprig of white and pink plum blossoms close to her chest.
```

### gh_mate_f_5 — 귀한 집 아씨 (찻잔)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), flawless soft skin, subtle natural makeup. Vertical 2:3 portrait, waist-up, exactly one young woman, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
An elegant noble young woman of twenty four with a dignified gentle expression. Black hair in an ornate updo with a gold and pearl crown ornament and long jeweled binyeo hairpins. Joseon-era court-style hanbok: a crimson and gold brocade dangui jacket over a white jeogori collar, a deep blue chima skirt with gold-stamped patterns, a red and gold norigae. She holds a small white porcelain teacup with both hands.
```

### gh_mate_f_6 — 여검객 (검)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), flawless soft skin, subtle natural makeup. Vertical 2:3 portrait, waist-up, exactly one young woman, slight three-quarter view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A spirited young swordswoman of twenty with confident bright eyes and a faint smile. Black hair tied in a high ponytail with a long white silk ribbon, loose strands framing her face. A martial-style Joseon hanbok: a white and sky blue jeogori with silver embroidery on the collar, sleeves bound at the wrists with blue cloth bands, a sky blue chima tied short for movement, a leather belt. She holds a sheathed sword upright in front of her shoulder with one hand.
```

## 남자 6종 (같은 화풍)

공통 화풍은 여자 쪽과 같고 `exactly one young woman` 만 `exactly one young man` 으로, 화장 문구를 뺐다.

### gh_mate_m_1 — 선비 (책)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), clean smooth skin. Vertical 2:3 portrait, waist-up, exactly one handsome young man, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A handsome young scholar of twenty two with a gentle intelligent smile. Neat black hair in a topknot under a black horsehair gat hat with a bead string. A white dopo robe over a pale blue inner robe with a dark collar, a thin blue sash. He holds a closed thread-bound book in one hand.
```

### gh_mate_m_2 — 검객 (검)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), clean smooth skin. Vertical 2:3 portrait, waist-up, exactly one handsome young man, slight three-quarter view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A handsome young swordsman of twenty four with a cool confident gaze. Long black hair tied high with a small silver crown ornament. A black and deep navy martial robe with silver embroidery on the collar, sleeves bound at the wrists, a dark leather belt. He rests one hand on the hilt of a sheathed sword at his side.
```

### gh_mate_m_3 — 귀공자 (부채)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), clean smooth skin. Vertical 2:3 portrait, waist-up, exactly one handsome young man, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A handsome young nobleman of twenty three with a calm warm smile. Black hair in a topknot held by a jade crown pin. A deep green brocade robe with gold-embroidered trim and a jade belt ornament. He holds a closed folding fan with a small tassel.
```

### gh_mate_m_4 — 순한 청년 (밀짚)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), clean smooth skin. Vertical 2:3 portrait, waist-up, exactly one handsome young man, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A kind handsome young man of twenty with a friendly bright smile. Black hair in a simple topknot tied with a cloth band. A sky blue cotton jeogori with a white collar and simple ribbon ties, plain and clean. He holds a small bundle of wildflowers in one hand.
```

### gh_mate_m_5 — 상단 후계자 (주판)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), clean smooth skin. Vertical 2:3 portrait, waist-up, exactly one handsome young man, slight three-quarter view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A handsome young merchant heir of twenty five with a charming confident smile. Black hair under a fine black horsehair gat hat. A maroon silk robe with a patterned gold collar and a small embroidered money pouch at the waist. He holds a small wooden abacus in one hand.
```

### gh_mate_m_6 — 무인 (흰옷)
```
Delicate semi-realistic Korean watercolor portrait illustration in the style of a premium historical drama character card. Fine ink line art with soft layered watercolor washes, realistic natural facial proportions, natural-sized eyes (not anime, not doll-like), clean smooth skin. Vertical 2:3 portrait, waist-up, exactly one handsome young man, front view, hands visible and naturally posed. Plain cream hanji paper background with subtle fiber texture, framed by a thin multicolored saekdong decorative border in gold, red, green and blue. Soft even light, refined and elegant. No text, no letters, no calligraphy, no seals, no signature, no watermark.
A handsome young martial artist of twenty two with gentle but sharp eyes. Long black hair loosely tied with a red cord, a few strands across his forehead. A white martial robe with a crimson inner collar, sleeves bound with white cloth, a red sash. His arms are crossed calmly in front of his chest.
```
