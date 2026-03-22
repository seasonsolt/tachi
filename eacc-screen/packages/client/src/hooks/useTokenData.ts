import { useMemo } from 'react';
import { useStore } from '../stores/store';
import { formatTokenCount, formatUSD, getNextMilestone } from '@eacc/shared';

export function useTokenData() {
  const tokenData = useStore((s) => s.tokenData);

  return useMemo(() => {
    if (!tokenData) {
      return {
        totalDisplay: '—',
        rateDisplay: '—/s',
        todayTokensDisplay: '—',
        todayCostDisplay: '$—',
        monthTokensDisplay: '—',
        monthCostDisplay: '$—',
        tokensPerSecond: 0,
        totalTokens: 0,
        nextMilestone: getNextMilestone(0),
        hasData: false,
      };
    }

    return {
      totalDisplay: formatTokenCount(tokenData.totalTokens),
      rateDisplay: `${tokenData.tokensPerSecond.toFixed(0)}/s`,
      todayTokensDisplay: formatTokenCount(tokenData.todayTokens),
      todayCostDisplay: formatUSD(tokenData.todayCostUSD),
      monthTokensDisplay: formatTokenCount(tokenData.monthTokens),
      monthCostDisplay: formatUSD(tokenData.monthCostUSD),
      tokensPerSecond: tokenData.tokensPerSecond,
      totalTokens: tokenData.totalTokens,
      nextMilestone: getNextMilestone(tokenData.totalTokens),
      hasData: true,
    };
  }, [tokenData]);
}
