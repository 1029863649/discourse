class Sanitize
  module Config
    DISCOURSE_ONEBOX ||=
      freeze_config merge(
                      ONEBOX,
                      attributes:
                        merge(ONEBOX[:attributes], 'aside' => %i[data])
                    )
  end
end
