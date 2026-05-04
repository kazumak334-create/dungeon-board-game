# ユニットイラスト プロンプトデータ

## グローバル共通プロンプト
（全ユニット共通・必ず含める）

```
pixel art, retro RPG style, 16-32px grain,
dark medieval dungeon, stone walls and floor, torch lighting,
single torch light source from lower-left, warm orange glow, deep shadows on right side,
no eyes, no facial features,
1-2px black pixel outline, no anti-aliasing, crisp pixel edges,
limited color palette 16-32 colors,
three-quarter front view, slight low angle,
subject fills 65% of frame, vertically centered,
scene-based composition, no standing pose,
transparent background, 270x330px
```

---

## 種族共通プロンプト

### スライム系共通
```
slime monster, translucent gel body, deep green and grey-green tones,
faint cyan phosphorescence, wet slimy surface texture
```

### 獣系共通
```
beast monster, fur or scaled body, muscular animal form,
natural predator, dungeon ecosystem creature
```

### アンデッド系共通
```
undead monster, decayed or spectral form, death magic aura,
dark purple and bone-white tones, faint green death glow
```

---

## グループ定義

---

### S1: 基本スライム（5体）

**グループ共通追加**:
```
basic slime variant, low-tier creature, damp dungeon floor environment
```

#### スライム（既存・参考用）
- Scene: 石床の水たまりの縁から複数の小スライムが這い出てきている
- Specific:
```
multiple small slimes crawling out of puddle on stone floor,
glistening green transparent bodies reflecting torchlight,
mossy wet stone surface with algae stains,
faint torch reflection shimmering in puddle water,
low angle wide shot, three slimes at different stages of emerging
```

#### Amoeba
- Scene: 崩れた石壁の亀裂から滲み出てきて体が変形している
- Specific:
```
semi-transparent blob seeping through narrow crack in crumbling stone wall,
body actively deforming and stretching to fit crevice shape,
pale grey-green translucent form with visible internal fluid movement,
torch light filtering through translucent body casting green glow on wall,
stone dust and pebbles falling from disturbed crack edges,
half of body through wall half still behind
```

#### Jelfix
- Scene: 石柱を触手で掴みながら天井から降下中
- Specific:
```
jellyfish-like slime with trailing tentacles descending along stone pillar,
three tentacles wrapped tightly around pillar surface for grip,
water dripping from mossy ceiling above,
translucent blue-green bell-shaped body,
dim torch light from corridor below casting upward shadow,
droplets of slime on pillar surface marking descent path
```

#### Mudblob
- Scene: 地下水路の泥底から半身を沈めて這い出てきている
- Specific:
```
mud-brown opaque blob half-submerged in thick silt,
front body hauling itself forward onto dry stone ledge,
muddy splash particles frozen mid-air around body,
gritty uneven texture with embedded sand gravel and small stones,
murky brown-green coloration darker than other slimes,
dark sewer tunnel arching overhead, distant torch far behind in mist
```

#### Barbzel
- Scene: 錆びた鉄格子の隙間を強引に通り抜けようとして変形している
- Specific:
```
blob forcing itself through gap between iron prison bars,
body grotesquely squeezed and bulging on both sides of bars,
rusted iron edges cutting grooves into gel body,
orange rust stains spreading into green body at contact points,
dark prison cell interior visible beyond bars,
single dying torch on far cell wall casting long bar shadows on floor
```

---

### S2: 毒・腐食スライム（6体）

**グループ共通追加**:
```
poison and corrosion slime variant, toxic purple-green tones,
caustic dripping fluid, corroded stone surfaces nearby
```

#### Venpool
- Scene: 石造りの水路に広がった毒の沼。毒液が石床を腐食させている
- Specific:
```
poison slime spreading across dungeon water channel floor,
caustic purple-green liquid pooling and corroding stone,
stone surface bubbling and dissolving at contact edges,
toxic mist rising from surface, dark veins spreading outward,
faint skull-shaped erosion pattern in stone
```

#### Plagzel
- Scene: 腐敗した死骸の上に乗っているスライム。周囲に感染の痕跡
- Specific:
```
plague slime sitting atop decomposed carcass on dungeon floor,
infection spreading as dark veins across surrounding stone,
bubbling pustules on slime surface, necrotic brown-green body,
rotting organic material being absorbed, dark spore cloud nearby
```

#### Sparkblob
- Scene: 石の壁に静電気を帯びながら張り付いている。電気火花が飛んでいる
- Specific:
```
electric slime clinging to stone wall surface,
crackling yellow-green sparks discharging across wall,
static electricity visible as hair-like tendrils reaching outward,
scorch marks on stone where sparks land, charged gel body with inner glow
```

#### Toxzel
- Scene: 天井の石の隙間から毒液を滴らせている。床に毒の水たまり
- Specific:
```
toxic slime hanging from ceiling crack, dripping poison onto floor below,
elongated drip tendrils stretching downward,
acid-yellow and green poison puddle forming on stone floor,
ceiling stone corroded and darkened around attachment point,
caustic fumes visible as wavy distortion around droplets
```

#### Pestzel
- Scene: 小さな虫の群れを体内に取り込んでいるスライム。虫の形が透けて見える
- Specific:
```
pestilence slime with swarm of tiny insects visible inside translucent body,
insects still moving within gel, some escaping from surface pores,
murky dark-green body less transparent than basic slime,
insect wing fragments and legs at body surface,
stone floor around covered in escaped insect shells
```

#### Blightzel
- Scene: 枯れた苔や菌類が生えた石壁に癒着しているスライム
- Specific:
```
blight slime fused with dead moss and fungi on dungeon wall,
body partially merged into stone surface, boundary unclear,
dead grey moss and black mushrooms growing from slime surface,
withered organic matter absorbed into body edges,
decay spreading outward from contact point on wall
```

---

### S3: 氷・結晶スライム（5体）

**グループ共通追加**:
```
ice and crystal slime variant, cold blue-white tones,
frost and crystalline structures, frozen dungeon environment
```

#### Crystel
- Scene: 水晶の生えた石壁の前。体内に結晶が育っている
- Specific:
```
crystal slime before wall covered in natural crystal formations,
geometric crystal shards growing inside translucent body,
blue-white internal structure refracting torch light into prisms,
crystal tips beginning to pierce through outer gel surface,
frost forming on nearby stone floor
```

#### Frostblob
- Scene: 凍った水たまりの上を滑っている。体が霜をまとっている
- Specific:
```
frost slime sliding across frozen puddle on dungeon floor,
white frost coating covering entire body surface,
ice crystals forming in wake behind movement,
breath-like frozen mist rising from cold body,
surrounding stone floor glazed with thin ice sheet
```

#### Crystalblast
- Scene: 結晶の破片を四方に射出した直後。床に結晶の破片が刺さっている
- Specific:
```
crystal slime immediately after launching crystal shards outward,
shrunken core body in center, depleted after blast,
sharp crystal fragments embedded in surrounding stone floor and walls,
refracted light from crystals creating rainbow patches,
cracks spreading from impact points in stone
```

#### Shieldblast
- Scene: 氷の盾膜を前方に展開して爆発転換している瞬間
- Specific:
```
shield slime with ice membrane on front face exploding outward,
blue-white ice shield shattering into projectile shards,
shockwave rings expanding forward from explosion point,
frozen core exposed behind shield remnants,
stone floor cracking from shockwave impact
```

#### Thornwall
- Scene: 棘状の氷柱を全身から生やしている。近づけない雰囲気
- Specific:
```
thorn slime covered in outward-pointing ice spike formations,
dense array of ice thorns radiating from body surface,
frost accumulation at base of each spike,
stone floor around covered in ice crystal deposits,
cold aura visible as white mist layer near ground
```

---

### S4: 魔法・沈黙スライム（5体）

**グループ共通追加**:
```
magic and silence slime variant, deep purple and void-black tones,
arcane suppression aura, magic-nullifying presence
```

#### Spellock
- Scene: 魔法陣の上に乗り、魔法陣の光を吸収している
- Specific:
```
spell-locking slime sitting on glowing magic rune circle,
actively absorbing and dimming the runes beneath it,
dark purple body with absorbed magic glowing faintly inside,
rune circle only partially visible where body does not cover,
arcane energy tendrils being drawn into body from circle
```

#### Nullock
- Scene: 空中に浮かぶ魔法の光球を吸い込んでいる
- Specific:
```
null slime absorbing floating magical orbs from the air,
three glowing orbs mid-absorption being pulled into body,
dark void-like center in body where magic disappears,
absorbed light creating brief bright flash at entry point,
surrounding air visibly darker as magic is drained
```

#### Voidblob
- Scene: 体の中心に小さな虚空の穴が開いている。周囲が歪んでいる
- Specific:
```
void slime with small dimensional hole visible at body center,
space warping and distorting around the void opening,
stones and debris near body slightly pulled toward void,
dark black opening contrasting with dark green body,
light bending around void opening creating halo effect
```

#### Silenzel
- Scene: 石廊下で静止している。周囲の音が消えたような静寂の雰囲気
- Specific:
```
silence slime perfectly still in dungeon corridor,
absolute stillness emanating outward as visible dark ripples,
nearby torch flame frozen and horizontal as if sound stopped,
no debris movement, dead calm area around body,
faint dark aura of soundlessness visible as void shimmer
```

#### Amplzel
- Scene: 他のスライムの隣で脈動している。隣のスライムが大きく見える
- Specific:
```
amplifier slime pulsing beside larger slime,
golden-purple amplification aura radiating outward from body,
neighboring slime visibly enlarged and glowing brighter,
rhythmic pulse waves expanding in rings from amplzel body,
connecting energy filament between the two slimes
```

---

### S5: 上位スライム（8体）

**グループ共通追加**:
```
elite slime variant, evolved form, large body, dungeon mid-level environment,
commanding presence among lesser slimes
```

#### キングスライム
- Scene: 石造りの玉座の間。小スライム3体が周囲を囲む中、王冠状突起を持つ巨大スライムが玉座から半身を乗り出している
- Specific:
```
king slime with crown-like protrusion on top, massive body size,
surrounded by three small slimes as subjects,
half-emerging from stone throne in dungeon throne room,
golden shimmer on crown protrusion, regal green body,
small slimes visibly deferring to large king body
```

#### Granob
- Scene: 地下採掘場の天井裂け目。岩石を取り込んで肥大化した巨大スライムが石柱を押しつぶしながら移動
- Specific:
```
massive mud-colored blob with rocks embedded inside body,
crushing stone pillar as it moves through mine tunnel,
visible rock fragments through translucent-murky body,
collapsing ceiling debris raining down,
stone floor cracking under enormous weight
```

#### Spinwall
- Scene: 回廊の交差点。棘を外側に向けて高速回転しながら壁面を削っている
- Specific:
```
spinning blob with spikes pointing outward in rotation,
motion blur on spikes indicating high speed spin,
stone wall being scraped and carved by spinning spikes,
stone chips flying outward from contact points,
circular groove carved into floor from spinning movement
```

#### Thornblast
- Scene: 爆発直後の地下空間。棘の束を四方に射出した後、中心で縮んでいる
- Specific:
```
blob after launching thorn volley in all directions,
shrunken depleted core in explosion center,
thorns embedded in stone floor walls and ceiling everywhere,
green splash debris and dust cloud from blast,
scorch marks radiating from blast center
```

#### Aegisblob
- Scene: 石廊下の中央。全身を半透明の膜が覆い、飛んできた矢を膜の外側で止めている
- Specific:
```
blob completely enveloped in translucent protective membrane,
three arrows stopped and stuck in outer membrane layer,
deep green body fully protected inside glowing pale blue membrane,
arrows suspended at various angles in membrane,
reflected torchlight on membrane surface
```

#### Ruinzel
- Scene: 崩壊した古代祭壇の前。廃墟化した石材を体内に取り込んで体表が石化しかけたように亀裂模様
- Specific:
```
blob with cracked stone-like texture on body surface,
collapsed ancient masonry partially absorbed into body,
crack lines spreading across body like broken stone,
sitting before broken stone idol in ruined altar room,
weathered grey-green coloration, dust and rubble on floor
```

#### Voidpool
- Scene: 深淵の縁。床の陥没した黒い空洞から半身を虚空に溶かし込んでいる
- Specific:
```
blob with lower half dissolving into bottomless black pit,
body fading from solid green to void darkness at pit edge,
bottomless pit visible below with no bottom,
remaining upper half glowing faint cyan-green,
stone edge of pit crumbling under body weight
```

---

### S6: 神スライム（6体）

**グループ共通追加**:
```
divine slime variant, ancient primordial form, self-luminous body,
no torchlight needed, deep dungeon final area,
awe-inspiring presence, otherworldly quality
```

#### Mothergel
- Scene: 繭状の空間の中心。無数の糸を壁に張り巡らせた巨大ゼリーが脈打ち、糸の先端から小スライムが生まれている
- Specific:
```
massive jelly creature at center of cocoon-like chamber,
countless bioluminescent filaments connecting body to all walls,
small slimes budding from filament tips,
pulsing translucent body, green bioluminescent threads,
deep cavern with no external light source, purely self-lit
```

#### Soulpool
- Scene: 石造りの礼拝堂跡の床一面に広がった銀色スライム。表面に人型の影が薄く映り込んでいる
- Specific:
```
silver liquid slime spread across entire floor of ruined chapel,
ghostly human silhouettes faintly visible reflected in surface,
rippling surface disturbed by unseen presence,
fallen stone statue partially submerged at center,
no torchlight, silver-white self-illumination
```

#### Primordialis
- Scene: 太古の溶岩跡が固まった地下空間。地層の割れ目から滲み出てきた原初スライムが岩盤と同化している
- Specific:
```
primordial slime seeping from cracks in ancient petrified lava,
body merging with rock wall, boundary between rock and slime unclear,
mineral crystals glowing deep red and green inside body,
dark basalt rock with glowing veins at contact with slime,
massive and ancient presence, geological scale
```

#### Voidking
- Scene: ダンジョン最深部の玉座の間。空間が歪む中心に黒と深青の巨大スライムが浮遊している
- Specific:
```
massive floating black and deep blue slime in deepest throne room,
space visibly warping and distorting around body,
stone blocks slowly being pulled into body at edges,
gravity distortion ripples visible as space bending,
dark self-emanated glow, abyss-like depth to body color
```

#### Gelarcane
- Scene: 魔法陣が刻まれた石床。円陣の中心に座り、触手で古代文字をなぞっている
- Specific:
```
slime sitting in center of glowing rune circle on stone floor,
tendril extended tracing glowing cyan symbols on floor,
rune circle responding to touch with brighter glow,
ancient script becoming clearer as traced,
deliberate intelligent movement, not random
```

#### Omniblob
- Scene: 崩れた天井からの一条の光の中。スライム・石・霧・炎の質感が同時に混在する不定形の巨体
- Specific:
```
shapeless massive entity caught in single shaft of ceiling light,
body showing stone texture in some areas, mist in others, flame in others,
all material textures coexisting simultaneously in one form,
liquid green core barely visible at center,
awe-inspiring frozen stillness in beam of light
```

---

### B1: 基本獣・前衛斥候（5体）

**グループ共通追加**:
```
beast monster, low-tier predator, dungeon front line creature,
natural animal coloring, wild and feral energy
```

#### ウルフ
- Scene: 廃墟の石廊下。低く身構えた狼が暗がりに向かって唸っている。背後に仲間の影
- Specific:
```
wolf crouching low in stone corridor snarling into darkness ahead,
fur bristling along spine, drool from bared fangs,
shadow silhouette of pack visible in darkness behind,
amber eyes reflecting torch light from side,
damp stone floor with paw prints in dust
```

#### ゴブリン
- Scene: 宝物庫の前。さびた短剣を握ったゴブリンが、宝箱の前でこちらを振り向いた瞬間
- Specific:
```
goblin caught turning from treasure chest to face viewer,
rusty short dagger raised in startled defensive grip,
surprised and hostile expression mid-turn,
torchlight hitting face dramatically from side,
green skin, ragged leather scraps as armor, scattered coins on floor
```

#### ケットシー
- Scene: 古い石棚の上。猫型妖精がこちらを見下ろしながら尻尾を揺らしている
- Specific:
```
cat fairy perched on high stone shelf looking down at viewer,
tail slowly swaying with predatory calm,
golden glowing eyes fixed downward on viewer,
black fur nearly invisible in darkness behind,
faint magical aura visible around paws, ancient carved shelf
```

#### Fangos
- Scene: 廃墟の入り口。崩れた石門を背に牙の目立つ肉食獣が立ちはだかっている
- Specific:
```
fanged predator beast blocking ruined stone gateway,
prominent jagged oversized fangs visible in open mouth,
claw marks gouged into stone doorposts on both sides,
blood trail dried on stone floor leading toward viewer,
torch from inside room rim-lighting the silhouette from behind
```

#### Lurker
- Scene: 天井の暗がり。壁と天井の境目に張り付いているトカゲ状の生物。目だけが光っている
- Specific:
```
lizard-like creature clinging to ceiling at junction with wall,
body perfectly camouflaged as stone-grey texture,
only two glowing yellow eyes visible in darkness,
adventurer boot prints on floor directly below,
water dripping past the creature from mossy ceiling
```

---

### B2: 飛行・速攻獣（5体）

**グループ共通追加**:
```
beast monster, aerial or fast-strike predator,
motion-forward pose, feathers or wings or speed indication
```

#### ワイルドホーク
- Scene: 石造りの吹き抜け空間。翼を広げて急降下してくる猛禽が爪を伸ばしている
- Specific:
```
raptor in steep dive with wings spread and talons fully extended,
diving straight down through stone shaft,
single feather falling loose from wing,
torch bracket on wall passing in blur beside dive path,
dark brown and amber feathers, fierce hunting focus
```

#### Ambushor
- Scene: 岩陰からの飛び出し直後。低い姿勢で跳躍し前爪を突き出した獣
- Specific:
```
beast caught mid-leap from behind boulder, front claws thrust forward,
low crouching launch posture, full body horizontal in air,
rock rubble and dust cloud from sudden launch,
grey and brown spotted fur, ambush moment frozen in time,
wide corridor behind showing the hiding spot
```

#### Strikehawk
- Scene: 石の柱の頂上。片翼を折りたたんだままこちらを狙う猛禽
- Specific:
```
hawk perched on stone pillar top with one wing partially folded,
other wing slightly open for balance, locking gaze downward at target,
claw marks visible on pillar top surface,
dust settling from recent landing, lightning bolt pattern on dark feathers,
stone pillar rising from dungeon floor below
```

#### Divehawk
- Scene: 水没した地下通路の水面すれすれを飛行。翼端を水面に触れさせている
- Specific:
```
hawk flying just above flooded corridor water surface,
wingtips grazing water creating small spray,
torch reflection in water rippling from wing disturbance,
low stone arched ceiling just above hawk,
dark blue-grey feathers with water droplets
```

#### Thornbeast
- Scene: 棘植物が絡まる廃墟の壁際。体表の棘が壁の棘草と同化するように立っている
- Specific:
```
quadruped beast standing near thorn-covered ruined wall,
natural spines on body matching thorn vine texture of wall,
body coloring blending with stone and vine environment,
stillness suggesting deliberate camouflage,
dark green-brown fur, spines along back and shoulders
```

---

### B3: 上位獣・特殊能力（6体）

**グループ共通追加**:
```
elite beast monster, special ability, dungeon mid-to-deep area,
distinctive physical feature, individual predator power
```

#### マンティコア
- Scene: 崩れた回廊の中央。ライオン型の胴体・蠍の尻尾を高く掲げ毒液を滴らせている
- Specific:
```
manticore with lion body and scorpion tail raised high overhead,
venom dripping from curved tail tip onto stone floor,
wings lowered to sides, glaring straight forward,
dark red and brown fur, spined tail segmentation visible,
stone rubble from collapsed corridor ceiling around feet
```

#### コカトリス
- Scene: 半壊した石牢の前。石化した冒険者の彫像が背後に立つ中、首を傾けてこちらを見ている
- Specific:
```
cockatrice tilting chicken head to one side, regarding viewer,
petrified stone statue of adventurer standing behind it,
green scaled serpent body, russet feathered head,
moment of eye contact implied by head angle,
cracked stone floor, single torch on far wall
```

#### Rageveil
- Scene: 血で染まった石床。怒りで歪んだ半透明の面が浮遊し、その下から実体のない爪が石床をひっかいている
- Specific:
```
floating translucent rage mask entity above bloodstained floor,
phantom claws extending downward scratching stone,
deep claw gouges and blood on floor below,
distorted furious expression on floating mask face,
dark red and purple aura, no solid body below the mask
```

#### 猛獣使い
- Scene: 広間の中央。むち傷のある革鎧の獣使いが、片手でウルフ2体の首輪の鎖を引いている
- Specific:
```
humanoid beastmaster holding chains of two wolves in one hand,
wolves crouching obediently with tensed muscles,
whip scars visible on scarred leather armor,
commanding forward stance, chain links gleaming in torch light,
dim hall with stone pillars on sides
```

#### Lancefang
- Scene: 石壁への突撃直前。牙が槍状に細長く伸びた獣が低姿勢で助走中
- Specific:
```
beast with elongated lance-like fang in full charge at stone wall,
low body angle with haunches powering forward thrust,
stone dust from run-up movement on floor,
chipped fang tip from previous impacts,
muscular dark fur body, white lance fang gleaming
```

#### Spearfang
- Scene: 獲物を仕留めた直後。槍牙を刺したまま顎を上げて咆哮
- Specific:
```
spear-fanged predator with fang piercing fallen prey on stone floor,
head thrown back mid-roar in victory,
blood spreading from prey onto surrounding stone,
torch light from directly above creating dramatic top-down shadows,
powerful scarred hide, victorious dominant posture
```

---

### B4: 神獣・伝説最強（6体）

**グループ共通追加**:
```
legendary beast, divine or mythical creature, deep dungeon encounter,
awe-inspiring scale, unique supernatural quality
```

#### タイガー
- Scene: 朽ちた石の祭壇の前。黒縞の巨大虎が頭蓋骨を足で転がしながら悠然と前を向いている
- Specific:
```
massive black-striped tiger calmly pawing skull off stone altar,
skull rolling on floor, tiger unbothered and confident,
torch light dramatically striping the coat pattern,
ancient altar with carved runes behind,
absolute calm dominance, no aggression needed
```

#### キリン
- Scene: 崩れた大広間。角から光の柱を放ちながら静かに歩いている。光が当たった石床に紋様が浮かぶ
- Specific:
```
mythical kirin walking slowly with pillar of golden light from horn,
light beam illuminating rune-like patterns appearing on stone floor,
golden-white scaled body, cloud-like mane,
cracked vaulted ceiling above, divine calm movement,
rune patterns glowing only where light touches
```

#### ビャッコ
- Scene: 霧に包まれた地下回廊の終端。白い虎が霧の中から半身だけ現れている
- Specific:
```
white tiger with only front half visible emerging from deep white mist,
rear half completely dissolved into mist, boundary invisible,
pale blue glowing eyes, only sharp feature in mist,
white fur blending at edges with white mist,
absolute silence implied by stillness, corridor end behind
```

#### グリフォン
- Scene: 石造りの塔の頂上。石の段を踏み崩しながら着地。翼を広げて仁王立ち
- Specific:
```
griffin landing on stone stairs, steps crumbling under impact weight,
wings spread wide in triumphant display,
stone dust and chunks flying from landing impact,
eagle head with fierce golden eyes, lion hindquarters,
moonlight shaft from ceiling crack above
```

#### フェンリル
- Scene: 鎖で繋がれた石の柱の前。太古の鎖を引きちぎった直後、自由になった四肢を地に踏みしめ咆哮
- Specific:
```
enormous wolf with broken ancient chains flying in air around it,
chain link ends still attached to stone pillars on both sides,
forepaws planted wide apart on cracked stone floor,
head thrown back in primal howl, dark fur crackling with energy,
paw impact cracks spreading through floor stones
```

#### Voidlance
- Scene: 次元の裂け目が走る地下空間。空間を貫く黒い穂先を持つ獣が現実と虚空の境界に立っている
- Specific:
```
beast with black lance protrusion piercing dimensional fabric,
body split at centerline: left half in stone dungeon, right half in void space,
dimensional crack running through floor and wall behind beast,
contrasting stone texture and void blackness meeting at body center,
void side showing no light, dungeon side torch-lit
```

---

### U1: 基本アンデッド・雑兵（5体）

**グループ共通追加**:
```
basic undead monster, low intelligence, remnant of the dead,
dungeon upper-level area, bone and rot materials
```

#### スケルトン
- Scene: 武具庫の前。さびた剣と盾を持ったスケルトンが衛兵のように立っている。骨の一部を拾おうとしている
- Specific:
```
skeleton soldier standing guard before weapon rack with rusted equipment,
one bone piece fallen on floor, skeleton bending slightly to retrieve it,
yellowed aged bones, leather straps holding armor fragments,
torchlight casting elongated rib cage shadow on wall behind,
rusted sword and cracked shield still in grip
```

#### グール
- Scene: 食堂跡の石テーブルの上。かじりかけの骨を手に座り込んでいる。空虚な瞳
- Specific:
```
ghoul sitting on stone table in ruined dining hall gnawing bone,
hollow completely empty eyes, mindless hunger expression,
rotting flesh with exposed bone patches on arms and face,
crumbling stone table, broken chairs and food debris around,
torch on distant wall barely reaching this corner
```

#### ワイト
- Scene: 古い石棺の隣。石棺の蓋を半分ずらして外へ這い出てきたワイト
- Specific:
```
wight crawling out of stone sarcophagus with lid pushed halfway off,
upper body out lower legs still inside coffin,
red glowing eyes, tattered burial wrappings trailing,
claw gouges on inside of lid visible from angle,
stone dust and cobwebs disturbed by emergence
```

#### カースシード
- Scene: 古い石床の亀裂から根を伸ばし、周囲の石床を腐食させている呪いの種
- Specific:
```
cursed seed sprouting dark roots through floor crack,
roots spreading outward corroding stone surface,
purple mist drifting from root tips,
skeleton bones nearby being entwined by advancing roots,
dark spreading stain on stone around crack origin
```

#### グリムハウル
- Scene: 石造りの礼拝堂廃墟。空洞の胸郭をさらけ出したアンデッド犬が石祭壇に前足をかけて遠吠え
- Specific:
```
undead dog with hollow empty ribcage visible through chest,
forepaws up on stone altar, head raised in long howl,
ghostly wispy forms rising from floor cracks in response to howl,
no organs inside visible ribcage, cracked stone altar,
ruined chapel pews in background
```

---

### U2: 中位アンデッド・魔術呪縛（5体）

**グループ共通追加**:
```
mid-tier undead with magical ability, spiritual power or curse,
dark purple and spectral blue tones, active ability in scene
```

#### バンシー
- Scene: 崩れた塔の踊り場。裂けた布を纏った霊体が手すりから身を乗り出して絶叫
- Specific:
```
spectral banshee in tattered shroud leaning over broken stone railing,
mouth wide open in silent visible scream,
visible sound waves expanding outward as ripple rings,
hair and fabric streaming upward against gravity,
pale self-luminous form, no solid body edges
```

#### カーシール
- Scene: 魔法陣の中心。両手から呪縛の鎖を射出している人型アンデッド。鎖の先端に目が見える
- Specific:
```
robed undead humanoid standing on floor rune circle,
binding chains launching from both outstretched hands,
small glowing eye visible at tip of each chain,
dark robe with curse runes glowing,
floor rune circle reacting to dark magic activation
```

#### シャドウ
- Scene: 松明が消えた暗がりの角。壁から分離した影が実体を持ち始めて廊下に立ち上がっている
- Specific:
```
shadow entity detaching from wall and gaining three-dimensional form,
transition between flat shadow and rising figure mid-process,
blurred indistinct body edges, only two red eyes sharp and defined,
extinguished torch still smoking nearby on wall sconce,
darkness deeper than surroundings within entity shape
```

#### レヴナント
- Scene: 戦場跡の廃墟。折れた剣を拾い上げているアンデッド戦士。意志を持った目
- Specific:
```
armored undead soldier crouching to pick up broken sword from rubble,
purposeful focused eyes, clear revenge-driven intent in posture,
heavily dented and scarred plate armor, missing visor,
battlefield debris and broken weapons around,
torch shadows creating dramatic face lighting
```

#### トレイトベイン
- Scene: 石造りの牢獄の格子の前。格子を握りしめ、格子が腐食して溶けかかっている
- Specific:
```
undead gripping iron prison bars from inside cell,
bars actively corroding and melting where hands grip them,
curse aura visibly eating metal as dark smoke,
hollow corrupted eyes staring through dissolving bars,
old chain on stone floor, darkness deep in cell behind
```

---

### U3: 上位アンデッド・術師召喚（4体）

**グループ共通追加**:
```
high-tier undead spellcaster or commander, intelligent undead,
commanding other undead, ritual environment
```

#### リッチ
- Scene: 腐った書架が並ぶ石造りの書斎跡。浮遊しながら魔法書のページをめくっている
- Specific:
```
skeletal lich hovering above floor in ruined underground library,
bony fingers turning pages of floating ancient tome,
intelligent gleam in hollow eye sockets, staff tip glowing pale blue,
rotting bookshelves with crumbling manuscripts behind,
floating bone fragments orbiting body slowly
```

#### 屍術師
- Scene: 解剖台の前。石の台に横たわる骨を指で再配列しながら儀式を執り行っている
- Specific:
```
robed skeletal necromancer rearranging bones on stone dissection table,
black thread-like energy extending from fingertips to bone pieces,
bones partially assembled, some floating mid-placement,
arcane tools and lens on table beside the work,
anatomical diagrams scratched into stone wall behind
```

#### デュラハン
- Scene: 暗い騎馬道。首のない甲冑騎士が自分の頭部を小脇に抱えながら黒い馬に乗っている
- Specific:
```
headless armored knight on black horse in dungeon mounted hall,
severed head tucked under left arm, head's eyes looking forward,
black horse with glowing red eyes, torchlight on plate armor,
horse hooves on stone floor, torch sconces on corridor walls,
imposing headless mounted silhouette
```

#### ヴリコラカス
- Scene: 地下窓の前。月光を受けながら人と獣の中間形態の吸血鬼が変容の途中で手が爪に変わりかけている
- Specific:
```
vampire mid-transformation between human and beast form at window alcove,
hands on window ledge with fingers actively elongating into claws,
skin tearing at finger joints revealing darker hide beneath,
moonlight through narrow window illuminating pale torn skin,
night sky barely visible through small window
```

---

### U4: 支配者アンデッド・王終極（2体）

**グループ共通追加**:
```
supreme undead ruler, dungeon boss tier, death embodiment,
massive or throne-room scale, fear-inducing presence
```

#### デスナイト
- Scene: 崩れた大扉の前。黒の全身甲冑に再起の紋章が刻まれた騎士が剣を地に突き立て片膝をついている。全身から黒い炎
- Specific:
```
fully black-armored death knight kneeling with greatsword thrust into stone floor,
resurrection rune glowing bright on chestplate,
black flames burning from all armor joint gaps,
broken grand gate behind, stone rubble piled around,
dramatic single knee down resurrection pose
```

#### 死骸の王座
- Scene: 無数の骨が積み重なった玉座。玉座そのものが意志を持ち、座面から腕のような骨が伸びて動いている
- Specific:
```
throne constructed entirely from skulls and bones, throne itself animated,
multiple bone arms extending from throne seat surface in different directions,
throne as living entity with intent, not just furniture,
lost adventurer equipment scattered at base of throne,
dim single shaft of light from far above, otherwise darkness
```
