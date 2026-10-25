#!/usr/bin/env python3
"""Rebuild the audio-free Scalar Guitar authored factory design."""
import json, math
from pathlib import Path
root=Path(__file__).resolve().parents[1]
amps=[1,.5,.6,.3,.4,.1,.25,.15,0,0]
phases=[0,.23,-.45,.12,.78,-.34,.55,-.19,.62,-.05]
def p(v,unit='normalized'):return dict(analyzed=None,model=v,offset=0,confidence=0,unit=unit)
def anchor(n,role='sustain'):
 reg=(n-66)/26
 return dict(midi=n,articulation=role,source='authored harmonic design',start=0,end=0,confidence=dict(pitch=0,harmonic=0,transient=0,resonance=0,overall=0),parameters=dict(f0=p(440*2**((n-69)/12),'Hz'),attackSeconds=p(.02,'s'),decaySeconds=p(5.76*(1-reg*.25),'s'),releaseSeconds=p(.15,'s'),harmonicAmplitudes=p([a*(i+1)**(reg*.12) for i,a in enumerate(amps)])),unsupported=['reference-audio measurements','learned pickup/body response','recorded articulations'])
base=json.loads((root/'presets/factory/nylon-string.json').read_text())
base.update(name='DBAL · Scalar Guitar',created='2026-10-25T00:00:00.000Z',classification=dict(name='Scalar Guitar',family='electric guitar'),provenance=[dict(source='User-supplied F-sharp additive guitar recipe',itemId='scalar-guitar-harmonic-recipe',rightsStatus='user-supplied design; new DSP implementation',redistributionPermitted=False,analysisDate=None,analyzerVersion=None,notes='Eight harmonic amplitudes retained from pasted text. No recordings, third-party DSP, or scalar-energy claims included.')])
base['capture']=dict(density=3,range=[40,88],analysisProfile='plucked')
base['anchors']=[anchor(n) for n in range(40,89,4)]
base['global']=dict(attackSeconds=p(.02,'s'),decaySeconds=p(5.76,'s'),releaseSeconds=p(.15,'s'),harmonicAmplitudes=p(amps),noise=p(.08))
base['registers']=[dict(name=name,**{'from':lo,'to':hi},parameters=dict(decaySeconds=p(5.76*(1-((lo+hi)/2-66)/26*.25),'s')),anchorPitches=[a['midi'] for a in base['anchors'] if lo<=a['midi']<=hi]) for name,lo,hi in [('Low strings',40,55),('Middle register',56,71),('Upper frets',72,88)]]
base['performance'].update(referenceHz=440,selectedArticulation='sustain',voiceMode='poly',velocityTrill=False,articulations=['sustain','trill','staccato','accent','breathy','alternate'],layers={role:[anchor(66,role)] for role in ['sustain','trill','staccato','accent','breathy','alternate']})
base['extensions']=dict(physicalModel=dict(version=1,kind='additive-string',origin='authored',continuous=False,hardness=.5,position=.25,noise=.08,decay=5.76,modes=[dict(ratio=i+1,gain=a,t60=5.76/(i+1)**.9,phase=phases[i]) for i,a in enumerate(amps)]),nativePerformance=dict(engineMode=4,volume=.7,bendRange=2,modulation=0),scalarControls=dict(pickup=1,vibratoDepth=.15,vibratoRate=5.6,bodyTexture=.2,room=.15,slideFrom=-2,auditionMidi=66),scalarGuitar=dict(version=2,range=[40,88],stringTuningMidi=[40,45,50,55,59,64],frets=24,referenceRecipeMidi=66,harmonicAmplitudes=amps,layerLabels=dict(sustain='Sustain / picked',trill='Generated trill',staccato='Palm mute',accent='Hard pick',breathy='Soft / finger',alternate='Harmonic'),notes='Authored starting voice. Continuous register response is calculated per note, not sampled. Layer descriptors are generated behaviors, not measured performances. Fixed body/pickup filter frequencies do not follow reference tuning.'))
base['performance']['glideMs']=300
base['extensions']['scalarGuitar']['defaultControls']=dict(base['extensions']['scalarControls'])
base['extensions']['scalarGuitar']['defaultGlideMs']=300
for path in [root/'presets/factory/scalar-guitar.json',root/'native/InstrumentDNA/Resources/scalar-guitar.json']:path.write_text(json.dumps(base,indent=2,ensure_ascii=False)+'\n')
manifest=json.loads((root/'presets/factory/manifest.json').read_text())
if not any(x['id']=='scalar-guitar' for x in manifest):manifest.append(dict(id='scalar-guitar',name=base['name'],path='presets/factory/scalar-guitar.json'))
if not any(x['id']=='scalar-guitar-original' for x in manifest):manifest.append(dict(id='scalar-guitar-original',name='DBAL · Scalar Guitar · Original',path='presets/factory/scalar-guitar-original.json'))
for path in [root/'presets/factory/manifest.json',root/'native/InstrumentDNA/Resources/manifest.json']:path.write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
