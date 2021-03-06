/*
 * Copyright (C) 2013 Google Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are
 * met:
 *
 *     * Redistributions of source code must retain the above copyright
 * notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above
 * copyright notice, this list of conditions and the following disclaimer
 * in the documentation and/or other materials provided with the
 * distribution.
 *     * Neither the name of Google Inc. nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
 * A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 * LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#ifndef SKY_ENGINE_CORE_ANIMATION_ANIMATIONTIMELINE_H_
#define SKY_ENGINE_CORE_ANIMATION_ANIMATIONTIMELINE_H_

#include "sky/engine/tonic/dart_wrappable.h"
#include "sky/engine/core/animation/AnimationEffect.h"
#include "sky/engine/core/animation/AnimationPlayer.h"
#include "sky/engine/core/dom/Element.h"
#include "sky/engine/platform/Timer.h"
#include "sky/engine/platform/heap/Handle.h"
#include "sky/engine/wtf/RefCounted.h"
#include "sky/engine/wtf/RefPtr.h"
#include "sky/engine/wtf/Vector.h"

namespace blink {

class Document;
class AnimationNode;

// AnimationTimeline is constructed and owned by Document, and tied to its lifecycle.
class AnimationTimeline : public RefCounted<AnimationTimeline>, public DartWrappable {
    DEFINE_WRAPPERTYPEINFO();
public:
    class PlatformTiming {

    public:
        // Calls AnimationTimeline's wake() method after duration seconds.
        virtual void wakeAfter(double duration) = 0;
        virtual void cancelWake() = 0;
        virtual void serviceOnNextFrame() = 0;
        virtual ~PlatformTiming() { }
    };

    static PassRefPtr<AnimationTimeline> create(Document*, PassOwnPtr<PlatformTiming> = nullptr);
    ~AnimationTimeline();

    void serviceAnimations(TimingUpdateReason);

    // Creates a player attached to this timeline, but without a start time.
    AnimationPlayer* createAnimationPlayer(AnimationNode*);
    AnimationPlayer* play(AnimationNode*);
    Vector<RefPtr<AnimationPlayer> > getAnimationPlayers();

#if !ENABLE(OILPAN)
    void playerDestroyed(AnimationPlayer* player)
    {
        ASSERT(m_players.contains(player));
        m_players.remove(player);
    }
#endif

    bool hasPendingUpdates() const { return !m_playersNeedingUpdate.isEmpty(); }
    double zeroTime() const { return 0; }
    double currentTime(bool& isNull);
    double currentTime();
    double currentTimeInternal(bool& isNull);
    double currentTimeInternal();
    double effectiveTime();
    void pauseAnimationsForTesting(double);

    void setOutdatedAnimationPlayer(AnimationPlayer*);
    bool hasOutdatedAnimationPlayer() const;

    Document* document() { return m_document.get(); }
#if !ENABLE(OILPAN)
    void detachFromDocument();
#endif
    void wake();

protected:
    AnimationTimeline(Document*, PassOwnPtr<PlatformTiming>);

private:
    RawPtr<Document> m_document;
    // AnimationPlayers which will be updated on the next frame
    // i.e. current, in effect, or had timing changed
    HashSet<RefPtr<AnimationPlayer> > m_playersNeedingUpdate;
    HashSet<RawPtr<AnimationPlayer> > m_players;

    friend class SMILTimeContainer;
    static const double s_minimumDelay;

    OwnPtr<PlatformTiming> m_timing;

    class AnimationTimelineTiming final : public PlatformTiming {
    public:
        AnimationTimelineTiming(AnimationTimeline* timeline)
            : m_timeline(timeline)
            , m_timer(this, &AnimationTimelineTiming::timerFired)
        {
            ASSERT(m_timeline);
        }

        virtual void wakeAfter(double duration) override;
        virtual void cancelWake() override;
        virtual void serviceOnNextFrame() override;

        void timerFired(Timer<AnimationTimelineTiming>*) { m_timeline->wake(); }

    private:
        RawPtr<AnimationTimeline> m_timeline;
        Timer<AnimationTimelineTiming> m_timer;
    };

    friend class AnimationAnimationTimelineTest;
};

} // namespace blink

#endif  // SKY_ENGINE_CORE_ANIMATION_ANIMATIONTIMELINE_H_
