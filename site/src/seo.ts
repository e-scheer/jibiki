interface LegalSchemaOptions {
  siteUrl: string;
  locale: string;
  homePath: string;
  currentPath: string;
  currentName: string;
}

export const makeLegalSchema = ({
  siteUrl,
  locale,
  homePath,
  currentPath,
  currentName,
}: LegalSchemaOptions) => [
  {
    '@context': 'https://schema.org',
    '@type': 'WebPage',
    name: currentName,
    url: `${siteUrl}${currentPath}`,
    inLanguage: locale,
    isPartOf: { '@type': 'WebSite', name: 'jibiki', url: siteUrl },
  },
  {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: [
      {
        '@type': 'ListItem',
        position: 1,
        name: 'jibiki',
        item: `${siteUrl}${homePath}`,
      },
      {
        '@type': 'ListItem',
        position: 2,
        name: currentName,
        item: `${siteUrl}${currentPath}`,
      },
    ],
  },
];
